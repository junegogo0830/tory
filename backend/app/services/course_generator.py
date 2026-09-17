import asyncio
import json
import logging
import math
import re

from anthropic import Anthropic, APIError

from ..core.config import settings
from ..db.redis import cache_get, cache_set
from ..models.course import CourseResponse, CourseStop
from ..models.location import LocationResponse
from .google_places import GooglePlacesService
from .photo_gallery import PhotoGalleryService
from .tourapi import TourApiService
from .tourism_filters import looks_non_touristy

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 3600 * 24 * 30  # 계절별 코스라 자주 안 바뀌어도 된다.
_SEARCH_RADIUS_M = 3000
_MODEL = "claude-haiku-4-5"


def _distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r1, r2 = math.radians(lat1), math.radians(lat2)
    dlat, dlng = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(r1) * math.cos(r2) * math.sin(dlng / 2) ** 2
    return 6371 * 2 * math.asin(min(1, math.sqrt(a)))

_SYSTEM_PROMPT = """당신은 "옛길" 앱의 동네 여행 코스 기획자입니다.
사용자가 예전에 살던 동네 근처를 오늘 다시 걸어보는 코스를 만듭니다.

규칙:
- 반드시 제공된 후보 목록에 있는 장소 이름만 정류지로 씁니다 (새로 지어내지 않음).
- 사용자가 설정한 시간·속도·관심 카테고리를 최우선으로 지킵니다.
- 식당은 코스 중간 또는 마지막에 한 곳만 배치하고 식사 60분을 배정합니다.
- 식당을 연달아 배치하지 말고 식사 전후에 관광지·문화시설·공원을 섞습니다.
- 후보 간 이동시간과 총 체류시간이 사용자 시간 안에 들어오는 순서만 선택합니다.
- 시간이 부족하면 장소 수를 줄이고 무리해서 후보를 나열하지 않습니다.
- 출력은 반드시 "{"로 시작해서 "}"로 끝나는 순수 JSON 하나뿐이어야 합니다.
  설명 문장, 인사말, ```json 같은 마크다운 코드블록을 절대 붙이지 마세요.

{
  "title": "코스 제목 (계절감이 드러나게)",
  "description": "1~2문장 소개",
  "duration_label": "약 N시간 형식",
  "category": "산책 | 역사 | 미식 중 하나",
  "sentiment_score": 0.0~1.0 사이 숫자 (이 코스가 얼마나 매력적인지),
  "stops": ["후보 목록에 있는 장소명 그대로", "..."]
}"""


_CODE_FENCE_RE = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.DOTALL)


def _extract_json(text: str) -> str:
    """Claude가 지침에도 불구하고 ```json 코드블록으로 감싸거나 앞뒤에 설명을
    붙이는 경우가 있어, 순수 JSON 객체만 뽑아낸다."""
    fenced = _CODE_FENCE_RE.search(text)
    if fenced:
        return fenced.group(1)

    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end != -1 and end > start:
        return text[start : end + 1]

    return text


class CourseGeneratorService:
    """관광사진이 실제로 있는 장소만 후보로 모아 LLM(Claude Haiku)이 계절별 코스를 짜게 한다.

    후보 선정 순서(반드시 이 순서):
    1. PhotoGalleryService(관광사진 정보 API)로 이 지역에 실제 사진이 있는
       장소를 찾는다 — 1차 Source of Truth.
    2. 각 후보를 TourApiService(국문 관광정보 API)와 장소명으로 매칭해
       좌표·주소·contentId·카테고리를 보강한다.
    3. 매칭에 성공하고 이 위치 반경 안에 있는 것만 최종 candidate pool이 된다.
    3-1. 그래도 후보가 2곳 미만이면(사진 갤러리 커버리지가 얕은 지역) 구글
       플레이스 Nearby Search로 좌표 반경 안 실제 장소를 추가로 찾아 채운다 —
       이쪽도 사진이 있는 결과만 후보로 쓴다.
    3-2. 그래도 2곳 미만이면(구글 Nearby Search도 이 근처 상권/시설을 인기도
       순으로 채워 실제 관광지가 상위에 안 잡히는 동네가 있다) TourApiService의
       좌표 기반 검색(locationBasedList2, contenttypeid=12)으로 마지막으로
       채운다 — 대표사진이 없는 결과가 섞일 수 있어 5번 단계의 사진 보강에 맡긴다.
    4. Claude는 이 pool에 있는 장소 이름만 골라 방문 순서를 정한다 — pool 밖
       이름을 반환해도 _parse_course가 무시한다(hallucination 방지).
    5. Claude가 고른 정류지 중에도(드물게) 사진이 비어 있으면 GooglePlacesService로
       마지막 한 번 더 보강한다 — 후보 자체는 위 세 소스가 보장하지만, 매칭
       과정에서 photo_url이 비는 극히 일부 경우를 위한 안전망이다.

    옛길 팀이 큐레이션한 3곳(순천/군산/영월)은 이 서비스를 타지 않고 기존
    RecommendationService의 손으로 다듬은 코스를 그대로 쓴다 — 여기는 그 3곳
    밖에서 검색으로 찾은 임의의 장소(예: 내가 살던 동네)를 위한 것이다.
    """

    def __init__(
        self,
        tour_api_service: TourApiService | None = None,
        photo_gallery_service: PhotoGalleryService | None = None,
        anthropic_client: Anthropic | None = None,
        google_places_service: GooglePlacesService | None = None,
    ) -> None:
        self._tour_api_service = tour_api_service or TourApiService()
        self._photo_gallery_service = photo_gallery_service or PhotoGalleryService()
        self._client = anthropic_client
        self._google_places_service = google_places_service or GooglePlacesService()

    def _get_client(self) -> Anthropic | None:
        if not settings.anthropic_api_key:
            return None
        if self._client is None:
            self._client = Anthropic(api_key=settings.anthropic_api_key, timeout=12, max_retries=0)
        return self._client

    async def generate_course(self, location: LocationResponse, season: str) -> CourseResponse | None:
        if location.latitude is None or location.longitude is None:
            return None

        # v7: 구글 Nearby Search도 얕은 동네를 위해 TourAPI 좌표 검색(3순위)을
        # 후보 소스에 추가 + 상호명 블랙리스트 적용 — 이전 캐시(그때는 후보가
        # 없어서 null로 캐싱됐을 수 있는 지역)를 무효화한다.
        cache_key = f"gencourse:v7:{location.id}:{season}"
        cached = await cache_get(cache_key)
        if cached is not None:
            course = CourseResponse.model_validate_json(cached) if cached != "null" else None
            if course:
                await cache_set(f"course-detail:v5:{course.id}", course.model_dump_json(), ex=_CACHE_TTL_SECONDS)
            return course

        course = await self._generate(location, season)

        await cache_set(cache_key, course.model_dump_json() if course else "null",
                        ex=_CACHE_TTL_SECONDS if course else 60)
        if course:
            await cache_set(f"course-detail:v5:{course.id}", course.model_dump_json(), ex=_CACHE_TTL_SECONDS)
        return course

    async def _generate(self, location: LocationResponse, season: str) -> CourseResponse | None:
        client = self._get_client()
        if client is None:
            return None

        candidates = await self._build_photo_backed_candidates(location)
        if len(candidates) < 2:
            return None

        candidate_lines = "\n".join(
            f"- {c['title']} ({c['category']}, {c['distance_m']}m, {c['addr']})" for c in candidates
        )
        user_prompt = (
            f"장소: {location.name} ({location.region})\n계절: {season}\n\n"
            f"반경 {_SEARCH_RADIUS_M}m 이내 실제 후보:\n{candidate_lines}\n\n"
            "방문 순서는 이동시간과 체류시간을 계산해 현실적으로 구성하세요. "
            "식당은 식사 60분을 포함하고 가장 적합한 한 곳만 선택하세요."
        )

        try:
            response = await asyncio.to_thread(client.messages.create,
                model=_MODEL,
                max_tokens=1024,
                system=_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_prompt}],
            )
        except APIError:
            logger.exception("Claude course generation failed for location_id=%s", location.id)
            return None

        text = next((block.text for block in response.content if block.type == "text"), "")
        course = self._parse_course(text, location=location, season=season, candidates=candidates)
        return await self._fill_missing_photos(course, location.region) if course is not None else None

    async def _photo_with_fallback(self, name: str, region: str, stop: CourseStop) -> dict | None:
        if stop.image_url is not None:
            return None  # 이미 있음(TourAPI/관광사진 API 출처라 출처 표기 불필요) — 그대로 둔다.
        photo = await self._google_places_service.find_photo(name, region)
        return photo  # {"image_url", "attribution_name", "attribution_url"} 또는 None.

    async def _fill_missing_photos(self, course: CourseResponse, region: str) -> CourseResponse:
        """Claude가 고른 정류지 중 TourAPI 사진이 없는 곳(식당류에 특히 흔하다)은
        구글 플레이스로 보강한다. 구글 사진은 이용약관상 출처 표기가 필요해서
        image_url과 함께 attribution도 정류지에 같이 저장한다."""
        photos = await asyncio.gather(
            *(self._photo_with_fallback(stop.name, region, stop) for stop in course.stops)
        )
        stops = [
            stop if photo is None else stop.model_copy(update={
                "image_url": photo["image_url"],
                "photo_attribution_name": photo["attribution_name"],
                "photo_attribution_url": photo["attribution_url"],
            })
            for stop, photo in zip(course.stops, photos, strict=True)
        ]
        image_url = course.image_url or next((s.image_url for s in stops if s.image_url), None)
        return course.model_copy(update={"stops": stops, "image_url": image_url})

    async def _build_photo_backed_candidates(self, location: LocationResponse) -> list[dict]:
        """Candidate pool 생성 — 반드시 관광사진 API가 먼저다.

        1) 관광사진 정보 API에서 이 지역 사진을 찾는다(장소명 텍스트만 얻음).
        2) 각 사진의 장소명을 국문 관광정보 API와 매칭해 좌표·주소·카테고리를 얻는다.
        3) 매칭에 성공하고, 좌표가 있고, 이 위치 반경(_SEARCH_RADIUS_M의 3배 —
           사진 API가 좌표 반경 검색을 지원하지 않아 느슨하게 잡는다) 안에 있는
           것만 최종 후보로 남긴다.
        4) 그래도 후보가 2곳 미만이면(관광사진 API 커버리지가 얕은 지역) 구글
           플레이스 Nearby Search로 좌표 반경 안 실제 장소를 추가로 찾아 채운다
           — 이쪽도 사진이 있는 결과만 후보로 쓴다(같은 "사진으로 검증된 곳만"
           원칙, 소스만 하나 늘어난 것).

        결과 dict는 기존 find_nearby_places()가 쓰던 키(title/category/distance_m/
        addr/latitude/longitude/image_url)와 같은 모양이라 _parse_course가
        그대로 쓸 수 있다 — 다른 건 image_url이 이제 항상 채워진다는 것뿐이다.
        """
        photos = await self._photo_gallery_service.search_photos(location.region, num_rows=30)
        if not photos:
            photos = await self._photo_gallery_service.search_photos(location.name, num_rows=30)

        seen_titles: set[str] = set()
        unique_photos = []
        for photo in photos:
            title = photo["title"]
            if not title or title in seen_titles:
                continue
            seen_titles.add(title)
            unique_photos.append(photo)

        async def resolve(photo: dict) -> dict | None:
            info = await self._tour_api_service.match_tour_info(photo["title"], location.region)
            if info is None or info["latitude"] is None or info["longitude"] is None:
                return None
            distance_km = _distance_km(location.latitude, location.longitude, info["latitude"], info["longitude"])
            if distance_km * 1000 > _SEARCH_RADIUS_M * 3:
                return None
            return {
                "title": info["name"],
                "category": info["category"],
                "distance_m": round(distance_km * 1000),
                "addr": info["address"],
                "latitude": info["latitude"],
                "longitude": info["longitude"],
                "image_url": photo["image_url"],
                "content_id": info["content_id"],
            }

        resolved = await asyncio.gather(*(resolve(p) for p in unique_photos))
        candidates: list[dict] = []
        candidate_titles: set[str] = set()
        for candidate in resolved:
            if candidate is not None and candidate["title"] not in candidate_titles:
                candidate_titles.add(candidate["title"])
                candidates.append(candidate)

        if len(candidates) < 2:
            nearby = await self._google_places_service.find_nearby(
                latitude=location.latitude, longitude=location.longitude, radius_m=_SEARCH_RADIUS_M
            )
            for place in nearby:
                if place["title"] in candidate_titles or looks_non_touristy(place["title"]):
                    continue
                candidate_titles.add(place["title"])
                distance_km = _distance_km(
                    location.latitude, location.longitude, place["latitude"], place["longitude"]
                )
                candidates.append({
                    "title": place["title"],
                    "category": "관광지",  # 구글 결과엔 TourAPI식 카테고리가 없어 기본값
                    "distance_m": round(distance_km * 1000),
                    "addr": place["address"],
                    "latitude": place["latitude"],
                    "longitude": place["longitude"],
                    "image_url": place["image_url"],
                    "photo_attribution_name": place.get("attribution_name"),
                    "photo_attribution_url": place.get("attribution_url"),
                    "content_id": None,
                })

        # 3순위 폴백: 관광사진 API도, 구글 인기순 상위 결과도 도움이 안 되는
        # 동네가 있다(실측 확인: 청명역 인근은 관광사진 API 0건, 구글 Nearby
        # Search 상위는 터널·옷가게뿐이라 사진 필터를 통과하는 게 하나도 없었음
        # — 정작 TourAPI 좌표 검색엔 공원 10곳이 잡혔다). TourAPI는 "인기순"이
        # 아니라 실제 등록 관광지를 좌표로 찾아주므로 마지막 순서로 추가한다.
        # 사진이 없는 결과가 섞일 수 있어(TourAPI 자체 대표사진 미등록) 이 항목은
        # _fill_missing_photos가 정류지로 뽑힌 뒤 구글로 한 번 더 보강을 시도한다.
        if len(candidates) < 2:
            tour_nearby = await self._tour_api_service.find_nearby_places(
                latitude=location.latitude, longitude=location.longitude,
                radius_m=_SEARCH_RADIUS_M, num_rows=20, content_type_id="12",
            )
            for place in tour_nearby:
                if (
                    place["title"] in candidate_titles
                    or place["latitude"] is None or place["longitude"] is None
                    or looks_non_touristy(place["title"])
                ):
                    continue
                candidate_titles.add(place["title"])
                candidates.append({
                    "title": place["title"],
                    "category": place.get("category", "관광지"),
                    "distance_m": place.get("distance_m"),
                    "addr": place.get("addr", ""),
                    "latitude": place["latitude"],
                    "longitude": place["longitude"],
                    "image_url": place.get("image_url"),
                    "content_id": None,
                })

        return candidates

    def _parse_course(
        self, text: str, *, location: LocationResponse, season: str, candidates: list[dict]
    ) -> CourseResponse | None:
        try:
            data = json.loads(_extract_json(text))
        except ValueError:
            logger.warning(
                "Claude course response was not valid JSON for location_id=%s: %r",
                location.id, text[:300],
            )
            return None

        if not isinstance(data, dict) or not isinstance(data.get("stops"), list):
            return None
        candidates_by_name = {c["title"]: c for c in candidates}
        stop_names = list(dict.fromkeys(s for s in data["stops"] if isinstance(s, str) and s in candidates_by_name))[:4]
        if len(stop_names) < 2:
            logger.warning("Claude course had too few real stops for location_id=%s", location.id)
            return None

        stops = [
            CourseStop(
                name=name,
                source="tourapi",
                latitude=candidates_by_name[name]["latitude"],
                longitude=candidates_by_name[name]["longitude"],
                category=candidates_by_name[name].get("category", ""),
                address=candidates_by_name[name].get("addr", ""),
                image_url=candidates_by_name[name].get("image_url"),
                photo_attribution_name=candidates_by_name[name].get("photo_attribution_name"),
                photo_attribution_url=candidates_by_name[name].get("photo_attribution_url"),
            )
            for name in stop_names
        ]

        try:
            return CourseResponse(
                id=f"llm-{location.id}-{season}",
                source="tourapi",
                location_id=location.id,
                title=str(data["title"]),
                description=str(data["description"]),
                sentiment_score=max(0.0, min(1.0, float(data["sentiment_score"]))),
                stops=stops,
                duration_label=str(data["duration_label"]),
                category=str(data.get("category", "산책")),
            )
        except (KeyError, ValueError, TypeError):
            logger.warning("Claude course response missing/invalid fields for location_id=%s", location.id)
            return None
