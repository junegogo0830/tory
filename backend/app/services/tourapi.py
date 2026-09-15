import asyncio
import datetime
import hashlib
import json
import logging
from urllib.parse import urlencode

import httpx

from ..core.config import settings
from ..core.text import extract_city, simplify_place_name, strip_html
from ..db.redis import cache_get, cache_set
from ..models.location import LocationResponse
from ..models.nearby_place import NearbyPlace
from .kakao_local import KakaoLocalService

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 3600
_IMAGE_CACHE_TTL_SECONDS = 3600 * 24


def _parse_coord(value: str | None) -> float | None:
    if not value:
        return None
    try:
        return float(value)
    except ValueError:
        return None


# TourAPI 4.0 contenttypeid 코드표.
_CONTENT_TYPE_LABELS = {
    "12": "관광지",
    "14": "문화시설",
    "15": "축제/행사",
    "25": "여행코스",
    "28": "레포츠",
    "32": "숙박",
    "38": "쇼핑",
    "39": "음식점",
}

# NOTE(2026-09-10): "전포동"은 부산 부산진구에 있는 실존 동이고 순천에는 없어서
# 카카오 로컬 지오코딩이 항상 실패했다(로드뷰 "위치를 찾지 못했어요"의 원인).
# 실제 순천 동명인 "저전동"으로 교체했다 — id 키(suncheon-jeonpo)는 여러 곳에서
# 참조하므로 그대로 두고 name/설명 콘텐츠만 바꿨다.
_MOCK_LOCATIONS: dict[str, LocationResponse] = {
    "suncheon-jeonpo": LocationResponse(
        id="suncheon-jeonpo",
        name="저전동 골목",
        region="전라남도 순천시",
        description="초등학교 등굣길이었던 골목길",
        past_year=1998,
        current_year=2026,
        is_cold_spot=False,
    ),
    "gunsan-jungang": LocationResponse(
        id="gunsan-jungang",
        name="중앙로 상가",
        region="전라북도 군산시",
        description="방과 후 친구들과 떡볶이를 먹던 거리",
        past_year=2003,
        current_year=2026,
        is_cold_spot=False,
    ),
    "yeongwol-jang": LocationResponse(
        id="yeongwol-jang",
        name="영월장 인근",
        region="강원도 영월군",
        description="할머니 손 잡고 다니던 오일장 골목",
        past_year=1995,
        current_year=2026,
        is_cold_spot=True,
    ),
}


class TourApiService:
    """TourAPI 4.0 연동 서비스.

    TOUR_API_KEY가 없으면(개발 초기/키 미발급 상태) 목 데이터를 반환한다.
    Redis에 조회 결과를 캐싱해 외부 API 호출을 줄인다.

    장소의 이름/연혁(과거·현재 연도, 설명)은 옛길 팀이 큐레이션한 값을 그대로 쓴다 —
    TourAPI는 일반 주거지 골목의 "몇 년도 모습이었는지" 같은 정보를 갖고 있지 않기
    때문이다. 대신 TourAPI 검색으로 실제 등록된 관광지와 매칭되면, 그 관광지의
    실제 현재 사진(firstimage)만 보강해서 붙인다. 매칭되는 관광지가 없으면
    image_url은 None으로 두고, 프론트엔드가 보유 정적 이미지로 폴백한다.
    """

    def __init__(self, kakao_local_service: KakaoLocalService | None = None) -> None:
        self._base_url = "https://apis.data.go.kr/B551011/KorService2"
        self._kakao_local_service = kakao_local_service or KakaoLocalService()

    async def _get(self, path: str, **params: object) -> dict:
        """data.go.kr이 발급하는 TOUR_API_KEY는 이미 퍼센트 인코딩된 값이라,
        httpx의 `params=` kwarg에 그대로 넘기면 httpx가 그 값을 한 번 더
        인코딩해(%2F → %252F) SERVICE_KEY_IS_NOT_REGISTERED_ERROR가 난다.
        serviceKey는 URL에 직접(raw) 붙이고 나머지만 urlencode한다 — 참고로
        완성된 쿼리스트링이 있는 URL에 httpx `params=`를 같이 넘기면 병합이
        아니라 그 쿼리스트링을 통째로 덮어써버리는 것도 확인했다.
        """
        query = urlencode(params)
        url = f"{self._base_url}/{path}?serviceKey={settings.tour_api_key}&{query}"
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(url)
            response.raise_for_status()
            return response.json()

    async def resolve_location(self, query: str) -> LocationResponse | None:
        """자유 입력(주소/학교/아파트 텍스트)에 대응하는 장소를 찾는다.

        옛길 팀이 큐레이션한 3곳(과거 사진이 실제로 준비된 곳) 중 하나와 매칭되면
        그 큐레이션 데이터를 그대로 쓴다. 매칭되지 않으면 카카오 로컬 API로 실시간
        검색해 실제 장소(이름/주소/좌표)를 채워 반환한다 — TourAPI 키워드 검색은
        "관광지"로 등록된 곳만 나와서 아파트·학교 같은 "내가 살던 곳" 검색엔 안 맞다.
        이 경우 큐레이션된 "그 시절" 사진이 없으므로 past_year는 current_year와
        같게 두고(비교 슬라이더는 의미 있는 과거 비교 없이 현재 모습만 보여준다),
        로드뷰·주변 관광지(TourAPI 좌표 기반 검색)로 현재 모습을 확인할 수 있다.
        둘 다 안 되면(카카오 키가 없거나 매칭도 없으면) None — 호출부가 404로 처리한다.
        """
        # v2: image_source_name(대체 사진 안내) 필드 추가로 스키마가 바뀌어 구버전
        # 캐시(예전엔 이 필드 없이 image_url만 있었고, 서울처럼 "시/군" 접미사 없는
        # 주소는 옛 로직에서 대체 사진도 못 찾아 image_url까지 null로 캐싱돼 있었다)를
        # 그대로 읽으면 필드 자체가 없거나 값이 틀려 보인다 — 키를 올려 자연스럽게 무효화한다.
        cache_key = f"location:v2:{query}"

        cached = await cache_get(cache_key)
        if cached is not None:
            return LocationResponse.model_validate(json.loads(cached)) if cached != "null" else None

        curated = self._match_curated(query)
        location = await self._enrich_curated(curated) if curated else await self._resolve_from_kakao(query)

        await cache_set(
            cache_key, location.model_dump_json() if location else "null", ex=_CACHE_TTL_SECONDS
        )

        return location

    def _match_curated(self, query: str) -> LocationResponse | None:
        for location in _MOCK_LOCATIONS.values():
            if location.name in query or location.region in query:
                return location
        return None

    async def _resolve_from_kakao(self, query: str) -> LocationResponse | None:
        results = await self._search_from_kakao(query, limit=1)
        return results[0] if results else None

    async def search_locations(self, query: str, limit: int = 5) -> list[LocationResponse]:
        """자동완성용: 검색어에 맞는 후보를 여러 개(최대 limit개) 반환한다.

        큐레이션된 3곳 중 매칭되는 게 있으면 맨 앞에 포함하고, 나머지는 카카오
        로컬 API 실시간 검색 결과로 채운다.
        """
        cache_key = f"locationsearch:v2:{query}:{limit}"  # v2: location:v2와 동일한 이유

        cached = await cache_get(cache_key)
        if cached is not None:
            return [LocationResponse.model_validate(item) for item in json.loads(cached)]

        results: list[LocationResponse] = []
        curated = self._match_curated(query)
        if curated is not None:
            results.append(await self._enrich_curated(curated))

        if len(results) < limit:
            kakao_results = await self._search_from_kakao(query, limit=limit - len(results))
            existing_ids = {r.id for r in results}
            results.extend(r for r in kakao_results if r.id not in existing_ids)

        await cache_set(
            cache_key, json.dumps([r.model_dump() for r in results]), ex=_CACHE_TTL_SECONDS
        )
        return results

    async def _search_from_kakao(self, query: str, limit: int) -> list[LocationResponse]:
        places = await self._kakao_local_service.search_places(query, limit=limit)
        current_year = datetime.date.today().year

        locations = []
        for place in places:
            # 이 장소 자체가 등록 관광지면(예: "수원화성") 그 사진을 먼저 쓴다 —
            # 대체 사진으로 바로 넘어가면 실제 명소까지 전부 대체 사진으로 뒤덮인다
            # (아파트·지하철역처럼 등록 안 된 곳만 대체 사진으로 폴백).
            own_image = await self.find_image_url(place["name"])
            image_url = own_image
            image_source_name = None
            if own_image is None:
                substitute = await self.find_photo_substitute(
                    latitude=place["latitude"], longitude=place["longitude"], address=place["address"]
                )
                if substitute is not None:
                    image_url = substitute["image_url"]
                    image_source_name = substitute["name"]
            location = LocationResponse(
                id=self._kakao_place_id(place),
                name=place["name"],
                region=place["address"],
                description="아직 큐레이션된 그 시절 사진은 없지만, 실시간 로드뷰와 주변 관광지로 지금 모습은 확인할 수 있어요.",
                past_year=current_year,
                current_year=current_year,
                is_cold_spot=False,
                source="kakao",
                image_url=image_url,
                image_source_name=image_source_name,
                latitude=place["latitude"],
                longitude=place["longitude"],
            )
            locations.append(location)
            # 카카오 REST API엔 "id로 상세 재조회" 엔드포인트가 없어서, 상세 화면
            # 진입(장소 ID로 직접 조회) 때 다시 찾을 수 있게 검색 시점에 미리 캐싱해둔다.
            await cache_set(
                f"locationdetail:v2:{location.id}", location.model_dump_json(), ex=_CACHE_TTL_SECONDS
            )

        return locations

    @staticmethod
    def _kakao_place_id(place: dict) -> str:
        if place["id"]:
            return f"kakao-{place['id']}"
        # 순수 주소 검색 결과는 카카오 장소 id가 없어 좌표로 안정적인 id를 만든다.
        digest = hashlib.sha1(f"{place['name']}{place['address']}".encode()).hexdigest()[:12]
        return f"kakao-{digest}"

    async def search_attractions(self, query: str, num_rows: int) -> list[LocationResponse]:
        """키워드로 등록 관광지(contentTypeId=12)만 검색한다 — HighlightService처럼
        검색 결과 자체(사진 포함)가 필요한 외부 호출부를 위한 공개 진입점."""
        return await self._search_from_tourapi(query, num_rows, content_type_id="12")

    async def search_restaurants(self, query: str, num_rows: int) -> list[LocationResponse]:
        """키워드로 등록 음식점(contentTypeId=39)만 검색한다 — 카테고리별 맛집
        발견 카드(DiscoveryService)를 위한 공개 진입점."""
        return await self._search_from_tourapi(query, num_rows, content_type_id="39")

    async def _search_from_tourapi(
        self, query: str, num_rows: int, *, content_type_id: str = "12"
    ) -> list[LocationResponse]:
        if not settings.tour_api_key:
            return []

        try:
            body = await self._get(
                "searchKeyword2",
                keyword=query,
                MobileOS="ETC",
                MobileApp="Yetgil",
                _type="json",
                numOfRows=num_rows,
                # contentTypeId으로 좁히고 사진 있는 것부터(arrange=O) 정렬한다.
                # 필터 없이 검색하면 같은 지명의 엉뚱한 업종이 뒤섞여 나온다
                # (예: "해운대" 검색 시 관광지 대신 다이소·안경점이 먼저 나오는 걸 확인함).
                contentTypeId=content_type_id,
                arrange="O",
            )
        except (httpx.HTTPError, ValueError):
            logger.exception("TourAPI keyword search failed for query=%s", query)
            return []

        items = body.get("response", {}).get("body", {}).get("items", "")
        item_list = items.get("item", []) if items else []
        current_year = datetime.date.today().year

        return [
            LocationResponse(
                id=f"tour-{item['contentid']}",
                name=item.get("title", query),
                region=item.get("addr1", "") or query,
                description="아직 큐레이션된 그 시절 사진은 없지만, 실시간 로드뷰로 지금 모습은 확인할 수 있어요.",
                past_year=current_year,
                current_year=current_year,
                is_cold_spot=False,
                source="tourapi",
                image_url=item.get("firstimage") or item.get("firstimage2") or None,
                latitude=_parse_coord(item.get("mapy")),
                longitude=_parse_coord(item.get("mapx")),
            )
            for item in item_list
        ]

    async def find_nearby_places(
        self,
        *,
        latitude: float,
        longitude: float,
        radius_m: int = 3000,
        num_rows: int = 15,
        content_type_id: str | None = None,
    ) -> list[dict]:
        """주어진 좌표 반경 내 실제 등록 장소를 거리순으로 반환한다 (코스 생성용 후보).

        도시 이름 매칭이 아니라 실제 좌표 기반 검색이라, "수원시"가 아니라 사용자가
        실제로 살던 동네(예: 영통구 특정 아파트) 좌표를 기준으로 "진짜 걸어갈 수
        있는 거리"의 장소만 나온다. content_type_id를 안 주면 좁히지 않는다 —
        코스에는 관광지뿐 아니라 공원·문화시설·식당이 섞이는 게 자연스럽다.
        `content_type_id="39"`처럼 넘기면 음식점만(주변 맛집 등) 좁혀서 찾는다.
        """
        if not settings.tour_api_key:
            return []

        params: dict[str, object] = {
            "MobileOS": "ETC",
            "MobileApp": "Yetgil",
            "_type": "json",
            "mapX": longitude,
            "mapY": latitude,
            "radius": radius_m,
            "numOfRows": num_rows,
            "arrange": "E",  # 거리순
        }
        if content_type_id:
            params["contentTypeId"] = content_type_id

        try:
            body = await self._get("locationBasedList2", **params)
        except (httpx.HTTPError, ValueError):
            logger.exception("TourAPI locationBasedList2 failed for (%s, %s)", latitude, longitude)
            return []

        items = body.get("response", {}).get("body", {}).get("items", "")
        item_list = items.get("item", []) if items else []

        return [
            {
                "title": item.get("title", ""),
                "category": _CONTENT_TYPE_LABELS.get(item.get("contenttypeid", ""), "기타"),
                "image_url": item.get("firstimage") or item.get("firstimage2") or None,
                "distance_m": round(float(item["dist"])) if item.get("dist") else None,
                "addr": item.get("addr1", ""),
                "latitude": _parse_coord(item.get("mapy")),
                "longitude": _parse_coord(item.get("mapx")),
            }
            for item in item_list
            if item.get("title")
        ]

    async def find_nearby_restaurants(
        self, location_id: str, *, radius_m: int = 1500, num_rows: int = 8
    ) -> list[NearbyPlace] | None:
        """장소 주변 실제 음식점을 거리순으로 반환한다. 좌표가 없는 장소면 None."""
        location = await self.get_location_by_id(location_id)
        if location is None or location.latitude is None or location.longitude is None:
            return None

        places = await self.find_nearby_places(
            latitude=location.latitude,
            longitude=location.longitude,
            radius_m=radius_m,
            num_rows=num_rows,
            content_type_id="39",
        )
        return [
            NearbyPlace(
                name=p["title"], category=p["category"], distance_m=p["distance_m"],
                address=p["addr"], latitude=p["latitude"], longitude=p["longitude"],
            )
            for p in places
        ]

    async def get_location_by_id(self, location_id: str) -> LocationResponse | None:
        if location_id.startswith("tour-"):
            return await self._get_tourapi_detail(location_id)

        if location_id.startswith("coords-"):
            # "현재 위치" 코스(RecommendationService.get_course_by_coords)가 만드는
            # 합성 id — 좌표가 id 자체에 그대로 박혀 있어 캐시 없이 재구성할 수
            # 있다. 코스를 id로 재조회할 때(예: 코스 상세 화면 새로고침) 쓰인다.
            try:
                lat_str, lng_str = location_id.removeprefix("coords-").split(",")
                latitude, longitude = float(lat_str), float(lng_str)
            except ValueError:
                return None
            current_year = datetime.date.today().year
            return LocationResponse(
                id=location_id, name="현재 위치", region="", description="",
                past_year=current_year, current_year=current_year, source="coords",
                latitude=latitude, longitude=longitude,
            )

        if location_id.startswith("kakao-"):
            # 카카오는 REST로 "id 상세 재조회"가 안 돼서, 검색 시점에 캐싱해둔
            # 걸 그대로 읽는다 — 캐시가 만료됐으면(30일) 찾을 수 없다.
            cached = await cache_get(f"locationdetail:v2:{location_id}")
            if cached is None or cached == "null":
                return None
            return LocationResponse.model_validate(json.loads(cached))

        location = _MOCK_LOCATIONS.get(location_id)
        if location is None:
            return None
        return await self._enrich_curated(location)

    async def _get_tourapi_detail(self, location_id: str) -> LocationResponse | None:
        """검색 결과에서 선택한 `tour-{contentId}` 장소를 상세 조회한다.

        `search_locations`/`resolve_location`이 만드는 id는 그때그때의 검색 결과라
        검색어 캐시로는 못 찾는다 — 상세 화면 진입(장소 ID로 직접 조회)을 위해
        TourAPI의 detailCommon2로 다시 조회하고, overview(실제 소개 문구)까지 채운다.
        """
        if not settings.tour_api_key:
            return None

        cache_key = f"locationdetail:v2:{location_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return LocationResponse.model_validate(json.loads(cached)) if cached != "null" else None

        content_id = location_id.removeprefix("tour-")
        try:
            body = await self._get(
                "detailCommon2",
                contentId=content_id,
                MobileOS="ETC",
                MobileApp="Yetgil",
                _type="json",
            )
        except (httpx.HTTPError, ValueError):
            logger.exception("TourAPI detail lookup failed for id=%s", location_id)
            return None

        items = body.get("response", {}).get("body", {}).get("items", "")
        item_list = items.get("item", []) if items else []
        if not item_list:
            await cache_set(cache_key, "null", ex=_CACHE_TTL_SECONDS)
            return None

        item = item_list[0]
        current_year = datetime.date.today().year
        overview = strip_html(item.get("overview") or "")
        own_image = item.get("firstimage") or item.get("firstimage2") or None
        latitude, longitude = _parse_coord(item.get("mapy")), _parse_coord(item.get("mapx"))
        image_url, image_source_name = own_image, None
        if own_image is None:
            substitute = await self.find_photo_substitute(
                latitude=latitude, longitude=longitude, address=item.get("addr1", "") or ""
            )
            if substitute is not None:
                image_url = substitute["image_url"]
                image_source_name = substitute["name"]
        location = LocationResponse(
            id=location_id,
            name=item.get("title", ""),
            region=item.get("addr1", "") or "",
            description=overview
            or "아직 큐레이션된 그 시절 사진은 없지만, 실시간 로드뷰로 지금 모습은 확인할 수 있어요.",
            past_year=current_year,
            current_year=current_year,
            is_cold_spot=False,
            source="tourapi",
            image_url=image_url,
            image_source_name=image_source_name,
            latitude=latitude,
            longitude=longitude,
        )

        await cache_set(cache_key, location.model_dump_json(), ex=_CACHE_TTL_SECONDS)
        return location

    async def get_all_locations(self) -> list[LocationResponse]:
        return list(
            await asyncio.gather(*(self._enrich_curated(loc) for loc in _MOCK_LOCATIONS.values()))
        )

    async def _enrich_curated(self, location: LocationResponse) -> LocationResponse:
        """큐레이션된 장소에 TourAPI 사진과 좌표(카카오 지오코딩)를 보강한다.

        좌표는 위치 기반 코스 추천(주변 실제 장소 검색)에 필요하다 — 큐레이션
        장소는 애초에 lat/lng을 갖고 있지 않으므로 로드뷰와 같은 방식으로 채운다.
        정확히 이 장소 이름으로 매칭되는 사진이 없으면(예: "저전동 골목"은
        등록 관광지가 아님) 시/군 대표 사진으로 한 번 더 폴백한다.
        """
        own_image, coords = await asyncio.gather(
            self.find_image_url(f"{location.region} {location.name}"),
            self._kakao_local_service.geocode(simplify_place_name(location.region, location.name)),
        )
        image_url, image_source_name = own_image, None
        if image_url is None:
            latitude, longitude = coords if coords is not None else (None, None)
            substitute = await self.find_photo_substitute(
                latitude=latitude, longitude=longitude, address=location.region
            )
            if substitute is not None:
                image_url = substitute["image_url"]
                image_source_name = substitute["name"]

        updates: dict[str, object] = {}
        if image_url is not None:
            updates["image_url"] = image_url
            updates["image_source_name"] = image_source_name
        if coords is not None:
            updates["latitude"], updates["longitude"] = coords
        return location.model_copy(update=updates) if updates else location

    async def get_city_image(self, address: str) -> str | None:
        """주소에서 시/군 단위를 뽑아 그 지역의 대표 관광지 사진을 반환한다.

        "수원시 영통구 OO아파트"처럼 특정 장소 자체엔 등록된 사진이 없어도,
        "수원시"로 검색하면 수원화성처럼 그 지역을 대표하는 유명한 곳이 잡힌다
        (검색 시 사진 있는 것부터 정렬하기 때문). 완전히 사진이 없는 것보다
        "이 동네가 있는 도시가 이런 곳"이라는 맥락을 주는 편이 낫다고 판단했다.
        """
        city = extract_city(address)
        if city is None:
            return None

        cache_key = f"cityimage:{city}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return cached or None

        # TourAPI 키워드 검색은 "수원시"처럼 시/군 접미사가 붙은 채로 넘기면 0건을
        # 반환한다("수원"은 정상 동작) — 접미사를 뗀 이름으로 검색한다.
        results = await self._search_from_tourapi(city.removesuffix("시").removesuffix("군"), num_rows=1)
        image_url = results[0].image_url if results else None
        await cache_set(cache_key, image_url or "", ex=_IMAGE_CACHE_TTL_SECONDS)
        return image_url

    async def find_photo_substitute(
        self, *, latitude: float | None, longitude: float | None, address: str
    ) -> dict | None:
        """이 장소 자신의 사진이 없을 때 보여줄 대체 사진을 찾는다.

        좌표가 있으면 반경 5km 내 사진이 있는 가장 가까운 등록 관광지를 먼저
        찾고(거리순 정렬이라 첫 매치가 최단 거리), 없으면 시/군 대표 관광지로
        폴백한다. 프론트엔드가 "OO 사진이 없어 가까운 XX 사진을 보여드려요"라고
        안내할 수 있도록 대체 사진의 실제 장소 이름도 함께 돌려준다.
        """
        if latitude is not None and longitude is not None:
            nearby = await self.find_nearby_places(
                latitude=latitude, longitude=longitude, radius_m=5000, num_rows=15, content_type_id="12"
            )
            match = next((p for p in nearby if p["image_url"]), None)
            if match is not None:
                return {"image_url": match["image_url"], "name": match["title"]}

        city = extract_city(address)
        if city is None:
            return None

        cache_key = f"citysubstitute:{city}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return json.loads(cached) if cached != "null" else None

        results = await self._search_from_tourapi(city.removesuffix("시").removesuffix("군"), num_rows=1)
        result = results[0] if results and results[0].image_url else None
        payload = {"image_url": result.image_url, "name": result.name} if result else None
        await cache_set(cache_key, json.dumps(payload) if payload else "null", ex=_IMAGE_CACHE_TTL_SECONDS)
        return payload

    async def find_image_url(self, keyword: str) -> str | None:
        """키워드로 등록된 관광지를 검색해 대표 사진 URL만 반환한다 (하위 호환 래퍼)."""
        info = await self.find_place_info(keyword)
        return info["image_url"] if info else None

    async def find_place_info(self, keyword: str) -> dict | None:
        """키워드로 등록된 관광지를 검색해 사진·좌표를 함께 반환한다.

        TOUR_API_KEY가 없거나, 매칭되는 관광지가 없거나, 요청이 실패하면 None —
        모두 정상적인 폴백 경로다 (일반 주거지 골목/큐레이션 코스 정류지는
        애초에 관광지로 등록돼 있지 않은 경우가 많다). 사진과 좌표를 한 캐시
        엔트리에 같이 저장해서, 코스 정류지 보강 때 사진·좌표를 각각 따로
        조회하느라 네트워크 호출을 두 번 하지 않게 한다.
        """
        if not settings.tour_api_key:
            return None

        cache_key = f"tourplace:{keyword}"

        cached = await cache_get(cache_key)
        if cached is not None:
            return json.loads(cached) if cached != "null" else None

        info = await self._search_first_place(keyword)
        await cache_set(cache_key, json.dumps(info) if info else "null", ex=_IMAGE_CACHE_TTL_SECONDS)

        return info

    async def _search_first_place(self, keyword: str) -> dict | None:
        try:
            body = await self._get(
                "searchKeyword2",
                keyword=keyword,
                MobileOS="ETC",
                MobileApp="Yetgil",
                _type="json",
                numOfRows=1,
            )
        except (httpx.HTTPError, ValueError):
            logger.exception("TourAPI place search failed for keyword=%s", keyword)
            return None

        items = body.get("response", {}).get("body", {}).get("items", "")
        if not items:
            return None
        item_list = items.get("item", [])
        if not item_list:
            return None

        first = item_list[0]
        return {
            "image_url": first.get("firstimage") or first.get("firstimage2") or None,
            "latitude": _parse_coord(first.get("mapy")),
            "longitude": _parse_coord(first.get("mapx")),
        }
