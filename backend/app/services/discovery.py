import asyncio
import json
import logging

from ..db.redis import cache_get, cache_set
from ..models.discovery import (
    KakaoRestaurantResponse,
    RestaurantCategoryResponse,
    RestaurantItemResponse,
    TopAttractionResponse,
)
from .kakao_local import KakaoLocalService
from .tourapi import TourApiService

logger = logging.getLogger(__name__)

_TOP_ATTRACTIONS_CACHE_KEY = "discovery:top-attractions"
_RESTAURANT_CATEGORIES_CACHE_KEY = "discovery:restaurant-categories"
_KAKAO_RESTAURANTS_CACHE_KEY = "discovery:kakao-restaurants"
_CACHE_TTL_SECONDS = 3600 * 24  # 하루에 한 번 재수집.

# 카카오맵 기반 "전국" 맛집 카드용 — 카카오 카테고리 검색은 좌표 기반이라 진짜
# "전국"은 없다. 주요 도시 중심 좌표를 돌며 모은 풀을 "전국"으로 대신한다.
_MAJOR_CITY_COORDS: dict[str, tuple[float, float]] = {
    "서울": (37.5665, 126.9780),
    "부산": (35.1587, 129.0603),
    "대구": (35.8697, 128.5936),
    "인천": (37.4563, 126.7052),
    "광주": (35.1495, 126.9165),
    "대전": (36.3504, 127.3845),
    "전주": (35.8154, 127.1530),
    "제주": (33.4996, 126.5312),
}
_KAKAO_RESTAURANTS_PER_CITY = 5
_KAKAO_NEARBY_RADIUS_M = 5000

# "실시간 검색 순위"를 낼 만한 자체 검색 로그 집계 인프라가 아직 없어서, 전국
# 대표 명소 10곳을 고정 순위로 두고 매일 캐시를 다시 채우는 정적 프록시로
# 대신한다. 진짜 실시간 인기도가 아니라는 점을 UI 카피에서도 과장하지 않는다
# ("인기 관광지 TOP 10" 정도로 — "실시간 검색 1위" 같은 표현은 쓰지 않는다).
_TOP_ATTRACTION_KEYWORDS = [
    "경복궁", "해운대해수욕장", "성산일출봉", "불국사", "남이섬",
    "전주한옥마을", "여수밤바다", "속초해수욕장", "담양죽녹원", "통영케이블카",
]

# 카테고리별 맛집 발견 카드. TourAPI 키워드 검색은 "한식 맛집"처럼 복합어를 넣으면
# 0건이 나온다(실제 호출로 확인 — "한식" 단독 18건, "한식 맛집" 0건). 카테고리
# 이름 단독 키워드로 검색한다.
_RESTAURANT_CATEGORIES: dict[str, str] = {
    "한식": "한식",
    "카페 · 디저트": "카페",
    "일식": "일식",
    "중식": "중식",
    "양식": "양식",
}
_RESTAURANTS_PER_CATEGORY = 4
_RESTAURANT_LIST_SIZE = 20  # 게시판형 "카테고리 맛집 목록" 화면에 쓰는 개수.


class DiscoveryService:
    """홈 화면 발견 콘텐츠(인기 관광지 TOP 10 티커, 카테고리별 맛집 카드) —
    둘 다 TourAPI 실제 데이터를 하루 단위로 캐싱해 재수집하는 동일한 패턴이다.
    """

    def __init__(
        self,
        tour_api_service: TourApiService | None = None,
        kakao_local_service: KakaoLocalService | None = None,
    ) -> None:
        self._tour_api_service = tour_api_service or TourApiService()
        self._kakao_local_service = kakao_local_service or KakaoLocalService()

    async def get_top_attractions(self) -> list[TopAttractionResponse]:
        cached = await cache_get(_TOP_ATTRACTIONS_CACHE_KEY)
        if cached is not None:
            return [TopAttractionResponse.model_validate(item) for item in json.loads(cached)]

        attractions = await self._build_top_attractions()
        await cache_set(
            _TOP_ATTRACTIONS_CACHE_KEY,
            json.dumps([item.model_dump() for item in attractions]),
            ex=_CACHE_TTL_SECONDS,
        )
        return attractions

    async def _build_top_attractions(self) -> list[TopAttractionResponse]:
        results = await asyncio.gather(
            *(self._tour_api_service.search_attractions(keyword, 1) for keyword in _TOP_ATTRACTION_KEYWORDS)
        )

        attractions: list[TopAttractionResponse] = []
        for rank, locations in enumerate(results, start=1):
            if not locations:
                continue
            location = locations[0]
            attractions.append(
                TopAttractionResponse(
                    rank=rank,
                    id=location.id,
                    name=location.name,
                    region=location.region,
                    image_url=location.image_url,
                )
            )

        if not attractions:
            logger.warning("Top attractions build returned no results (TOUR_API_KEY missing?)")
        return attractions

    async def get_restaurant_categories(self) -> list[RestaurantCategoryResponse]:
        cached = await cache_get(_RESTAURANT_CATEGORIES_CACHE_KEY)
        if cached is not None:
            return [RestaurantCategoryResponse.model_validate(item) for item in json.loads(cached)]

        categories = await self._build_restaurant_categories()
        await cache_set(
            _RESTAURANT_CATEGORIES_CACHE_KEY,
            json.dumps([category.model_dump() for category in categories]),
            ex=_CACHE_TTL_SECONDS,
        )
        return categories

    async def _build_restaurant_categories(self) -> list[RestaurantCategoryResponse]:
        results = await asyncio.gather(
            *(
                self._tour_api_service.search_restaurants(keyword, _RESTAURANTS_PER_CATEGORY)
                for keyword in _RESTAURANT_CATEGORIES.values()
            )
        )

        categories: list[RestaurantCategoryResponse] = []
        for category, locations in zip(_RESTAURANT_CATEGORIES.keys(), results, strict=True):
            items = [
                RestaurantItemResponse(
                    id=location.id, name=location.name, region=location.region, image_url=location.image_url
                )
                for location in locations
                if location.image_url is not None
            ]
            if not items:
                continue
            categories.append(RestaurantCategoryResponse(category=category, headline=category, items=items))

        if not categories:
            logger.warning("Restaurant categories build returned no results (TOUR_API_KEY missing?)")
        return categories

    async def get_restaurants_by_category(self, category: str) -> list[RestaurantItemResponse]:
        """"자세히보기"로 들어가는 카테고리 전체 목록 — 전국 키워드 검색 결과를
        하루 단위로 캐싱한다(홈 화면 카드용 4개 풀과는 별도 캐시)."""
        keyword = _RESTAURANT_CATEGORIES.get(category)
        if keyword is None:
            return []

        cache_key = f"discovery:restaurants:{category}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [RestaurantItemResponse.model_validate(item) for item in json.loads(cached)]

        locations = await self._tour_api_service.search_restaurants(keyword, _RESTAURANT_LIST_SIZE)
        items = [
            RestaurantItemResponse(
                id=location.id, name=location.name, region=location.region, image_url=location.image_url
            )
            for location in locations
            if location.image_url is not None
        ]
        await cache_set(cache_key, json.dumps([item.model_dump() for item in items]), ex=_CACHE_TTL_SECONDS)
        return items

    async def get_kakao_restaurants_nationwide(self) -> list[KakaoRestaurantResponse]:
        """카카오맵 기반 "전국" 맛집 카드 — 주요 도시 중심 좌표를 돌며 모은 풀을
        하루 단위로 캐싱한다. 카카오 응답엔 사진이 없어 이름/카테고리/주소만 있다.
        """
        cached = await cache_get(_KAKAO_RESTAURANTS_CACHE_KEY)
        if cached is not None:
            return [KakaoRestaurantResponse.model_validate(item) for item in json.loads(cached)]

        results = await asyncio.gather(
            *(
                self._kakao_local_service.search_restaurants(
                    latitude=lat, longitude=lng, limit=_KAKAO_RESTAURANTS_PER_CITY
                )
                for lat, lng in _MAJOR_CITY_COORDS.values()
            )
        )
        restaurants = [
            KakaoRestaurantResponse(
                id=place["id"], name=place["name"], category=place["category"], address=place["address"]
            )
            for places in results
            for place in places
            if place.get("id")
        ]
        if not restaurants:
            logger.warning("Kakao nationwide restaurants build returned no results (KAKAO_REST_API_KEY missing?)")
        await cache_set(
            _KAKAO_RESTAURANTS_CACHE_KEY,
            json.dumps([r.model_dump() for r in restaurants]),
            ex=_CACHE_TTL_SECONDS,
        )
        return restaurants

    async def get_kakao_restaurants_nearby(
        self, *, latitude: float, longitude: float
    ) -> list[KakaoRestaurantResponse]:
        """카카오맵 기반 "내 주변" 맛집(반경 5km) — 위치에 따라 매번 달라지므로 캐싱하지 않는다."""
        places = await self._kakao_local_service.search_restaurants(
            latitude=latitude, longitude=longitude, radius_m=_KAKAO_NEARBY_RADIUS_M, limit=15
        )
        return [
            KakaoRestaurantResponse(
                id=place["id"],
                name=place["name"],
                category=place["category"],
                address=place["address"],
                distance_m=place.get("distance_m"),
            )
            for place in places
            if place.get("id")
        ]
