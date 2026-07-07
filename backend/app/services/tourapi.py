import json
import logging

import httpx

from ..core.config import settings
from ..db.redis import get_redis
from ..models.location import LocationResponse

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 3600

_MOCK_LOCATIONS: dict[str, LocationResponse] = {
    "suncheon-jeonpo": LocationResponse(
        id="suncheon-jeonpo",
        name="전포동 골목",
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
    """

    def __init__(self) -> None:
        self._base_url = "https://apis.data.go.kr/B551011/KorService2"

    async def resolve_location(self, query: str) -> LocationResponse:
        cache_key = f"location:{query}"
        redis = get_redis()

        try:
            cached = await redis.get(cache_key)
            if cached:
                return LocationResponse.model_validate(json.loads(cached))
        except Exception:  # noqa: BLE001 — 캐시 장애는 무시하고 계속 진행
            logger.warning("Redis unavailable, skipping cache lookup", exc_info=True)

        location = await self._fetch_location(query)

        try:
            await redis.set(cache_key, location.model_dump_json(), ex=_CACHE_TTL_SECONDS)
        except Exception:  # noqa: BLE001
            logger.warning("Redis unavailable, skipping cache write", exc_info=True)

        return location

    async def _fetch_location(self, query: str) -> LocationResponse:
        if not settings.tour_api_key:
            return self._mock_for_query(query)

        try:
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(
                    f"{self._base_url}/searchKeyword2",
                    params={
                        "serviceKey": settings.tour_api_key,
                        "keyword": query,
                        "MobileOS": "ETC",
                        "MobileApp": "Yetgil",
                        "_type": "json",
                    },
                )
                response.raise_for_status()
                # TODO: 실제 TourAPI 응답 스키마에 맞춰 LocationResponse로 매핑.
                return self._mock_for_query(query)
        except httpx.HTTPError:
            logger.exception("TourAPI request failed, falling back to mock data")
            return self._mock_for_query(query)

    def _mock_for_query(self, query: str) -> LocationResponse:
        for location in _MOCK_LOCATIONS.values():
            if location.name in query or location.region in query:
                return location
        return _MOCK_LOCATIONS["suncheon-jeonpo"]

    async def get_location_by_id(self, location_id: str) -> LocationResponse | None:
        return _MOCK_LOCATIONS.get(location_id)
