import json
import logging

import httpx

from ..core.config import settings
from ..db.redis import cache_get, cache_set

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 3600 * 24 * 30  # 좌표는 거의 바뀌지 않으므로 길게 캐싱.


class KakaoLocalService:
    """카카오 로컬 API로 지명/주소를 좌표로 변환한다.

    KAKAO_REST_API_KEY가 없으면 항상 빈 결과/None — 호출부가 "찾지 못했어요"
    같은 빈 상태로 폴백한다.
    """

    _BASE_URL = "https://dapi.kakao.com/v2/local/search"
    _GEO_BASE_URL = "https://dapi.kakao.com/v2/local/geo"

    async def geocode(self, query: str) -> tuple[float, float] | None:
        """(latitude, longitude) 튜플을 반환한다. 실패하면 None. (로드뷰 위치 지정용)"""
        if not settings.kakao_rest_api_key:
            return None

        cache_key = f"geocode:{query}"

        cached = await cache_get(cache_key)
        if cached is not None:
            if cached == "":
                return None
            lat_str, lng_str = cached.split(",")
            return float(lat_str), float(lng_str)

        coords = await self._search_address(query) or await self._search_keyword(query)
        await cache_set(cache_key, f"{coords[0]},{coords[1]}" if coords else "", ex=_CACHE_TTL_SECONDS)

        return coords

    async def reverse_geocode(self, latitude: float, longitude: float) -> str | None:
        """좌표를 "경기 수원시 영통구" 같은 시군구 단위 지역명으로 바꾼다.

        커뮤니티 "내 동네" 자동 설정에 쓴다 — 구/군이 있으면 "시/도 시군구",
        없으면(세종시 등) "시/도" 자체를 돌려준다. 실패하면 None.
        """
        if not settings.kakao_rest_api_key:
            return None

        cache_key = f"reversegeocode:{latitude:.5f},{longitude:.5f}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return cached or None

        region = await self._request_region(latitude, longitude)
        await cache_set(cache_key, region or "", ex=_CACHE_TTL_SECONDS)
        return region

    async def _request_region(self, latitude: float, longitude: float) -> str | None:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(
                    f"{self._GEO_BASE_URL}/coord2regioncode.json",
                    headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
                    params={"x": longitude, "y": latitude},
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            logger.exception("Kakao reverse geocode failed for lat=%s lng=%s", latitude, longitude)
            return None

        documents = [doc for doc in body.get("documents", []) if doc.get("region_type") == "H"]
        if not documents:
            documents = body.get("documents", [])
        if not documents:
            return None

        doc = documents[0]
        parts = [doc.get(f"region_{n}depth_name") for n in (1, 2)]
        region = " ".join(part for part in parts if part)
        return region or None

    async def _search_address(self, query: str) -> tuple[float, float] | None:
        return await self._request("/address.json", query, "address")

    async def _search_keyword(self, query: str) -> tuple[float, float] | None:
        return await self._request("/keyword.json", query, "keyword")

    async def _request(self, path: str, query: str, kind: str) -> tuple[float, float] | None:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(
                    f"{self._BASE_URL}{path}",
                    headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
                    params={"query": query},
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            logger.exception("Kakao Local %s search failed for query=%s", kind, query)
            return None

        documents = body.get("documents", [])
        if not documents:
            return None

        first = documents[0]
        try:
            return float(first["y"]), float(first["x"])
        except (KeyError, ValueError):
            return None

    async def search_restaurants(
        self,
        *,
        latitude: float,
        longitude: float,
        radius_m: int = 5000,
        limit: int = 15,
        sort: str = "distance",
    ) -> list[dict]:
        """좌표 반경 내 실제 음식점(카테고리 코드 FD6)을 반환한다.

        카카오 로컬 API 응답엔 평점/리뷰 수/사진 필드가 아예 없다(실제 호출로
        확인 — id/place_name/category_name/address_name/road_address_name/
        phone/place_url/x/y/distance뿐). "인기순" 정렬은 이 API로는 낼 수 없어,
        카카오 자체 관련도 랭킹(`sort="accuracy"`)이나 거리순(`sort="distance"`,
        기본값 — "내 주변"처럼 실제로 가까운 곳이 우선이어야 할 때)을 호출부가
        고른다. 카카오는 TourAPI보다 등록 밀도가 훨씬 높아서(같은 반경 기준
        실측 최대 10배 이상) "카카오맵 기반" 맛집 카드의 데이터 소스로 쓴다.
        """
        if not settings.kakao_rest_api_key:
            return []

        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(
                    f"{self._BASE_URL}/category.json",
                    headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
                    params={
                        "category_group_code": "FD6",
                        "x": longitude,
                        "y": latitude,
                        "radius": radius_m,
                        "size": min(limit, 15),
                        "sort": sort,
                    },
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            logger.exception("Kakao category(FD6) search failed for (%s, %s)", latitude, longitude)
            return []

        results: list[dict] = []
        for doc in body.get("documents", []):
            try:
                lat, lng = float(doc["y"]), float(doc["x"])
            except (KeyError, ValueError):
                continue
            results.append(
                {
                    "id": doc.get("id") or "",
                    "name": doc.get("place_name") or "",
                    "category": (doc.get("category_name") or "").split(">")[-1].strip() or "음식점",
                    "address": doc.get("road_address_name") or doc.get("address_name", ""),
                    "distance_m": int(doc["distance"]) if doc.get("distance") else None,
                    "latitude": lat,
                    "longitude": lng,
                    "phone": doc.get("phone") or None,
                    "place_url": doc.get("place_url") or None,
                }
            )
        return results

    async def search_places(self, query: str, limit: int = 5) -> list[dict]:
        """자유 입력(주소/학교/아파트 등)에 맞는 실제 장소 후보를 찾는다.

        TourAPI 키워드 검색과 달리 "관광지"로 등록된 곳만 나오지 않는다 — 아파트
        단지, 학교, 동네 이름 등 카카오맵에 있는 모든 실제 장소가 대상이라
        "내가 살던 곳" 검색에 훨씬 잘 맞는다. 키워드 검색으로 먼저 찾고, 결과가
        없으면(순수 행정구역 주소 등) 주소 검색으로 한 번 더 시도한다.
        """
        if not settings.kakao_rest_api_key:
            return []

        cache_key = f"kakaoplaces:{query}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return json.loads(cached)

        results = await self._search_places_multi("/keyword.json", query, limit)
        if not results:
            results = await self._search_places_multi("/address.json", query, limit)

        await cache_set(cache_key, json.dumps(results), ex=_CACHE_TTL_SECONDS)
        return results

    async def search_schools(self, query: str, limit: int = 8) -> list[dict]:
        """학교 이름 검색 — 카테고리 코드 SC4(학교)로 필터링해 다른 장소가 섞이지 않게 한다."""
        if not settings.kakao_rest_api_key:
            return []

        cache_key = f"kakaoschools:{query}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return json.loads(cached)

        results = await self._search_places_multi(
            "/keyword.json", query, limit, category_group_code="SC4"
        )

        await cache_set(cache_key, json.dumps(results), ex=_CACHE_TTL_SECONDS)
        return results

    async def _search_places_multi(
        self, path: str, query: str, limit: int, *, category_group_code: str | None = None
    ) -> list[dict]:
        params: dict[str, str | int] = {"query": query, "size": limit}
        if category_group_code:
            params["category_group_code"] = category_group_code
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(
                    f"{self._BASE_URL}{path}",
                    headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
                    params=params,
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            logger.exception("Kakao Local place search failed for query=%s", query)
            return []

        results: list[dict] = []
        for doc in body.get("documents", []):
            try:
                latitude, longitude = float(doc["y"]), float(doc["x"])
            except (KeyError, ValueError):
                continue

            if path == "/keyword.json":
                place_id = doc.get("id") or ""
                name = doc.get("place_name") or query
                address = doc.get("road_address_name") or doc.get("address_name", "")
            else:  # /address.json — 장소가 아니라 순수 주소라 place_name/id가 없다.
                place_id = ""
                address = doc.get("address_name", "")
                name = address or query

            results.append(
                {
                    "id": place_id,
                    "name": name,
                    "address": address,
                    "latitude": latitude,
                    "longitude": longitude,
                }
            )

        return results
