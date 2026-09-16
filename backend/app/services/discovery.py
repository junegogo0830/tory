import asyncio
import json
import logging

from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.text import extract_city
from ..db.models import SavedLocation
from ..db.redis import cache_get, cache_set
from ..models.discovery import (
    KakaoRestaurantResponse,
    RestaurantCategoryResponse,
    RestaurantItemResponse,
    TopAttractionResponse,
)
from ..models.location import LocationResponse, PopularLocationResponse
from .google_places import GooglePlacesService
from .kakao_local import KakaoLocalService
from .tourapi import TourApiService

logger = logging.getLogger(__name__)

_TOP_ATTRACTIONS_CACHE_KEY = "discovery:top-attractions:v3"
_RESTAURANT_CATEGORIES_CACHE_KEY = "discovery:restaurant-categories:v3"
_KAKAO_RESTAURANTS_CACHE_KEY = "discovery:kakao-restaurants:v3"
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

# 지역 캐러셀("내 주변" GPS를 대체) — 사용자가 직접 고르는 7개 광역권 대표 좌표.
# 도 단위(경기/전라/경상/강원)는 그 지역의 중심에 가까운 주요 도시로 앵커링한다.
_REGION_COORDS: dict[str, tuple[float, float]] = {
    "서울": (37.5665, 126.9780),
    "부산": (35.1587, 129.0603),
    "경기": (37.2911, 127.0089),  # 수원
    "대전": (36.3504, 127.3845),
    "전라": (35.8242, 127.1480),  # 전주
    "경상": (35.8714, 128.6014),  # 대구
    "강원": (37.8228, 128.1555),  # 춘천
}
_KAKAO_RESTAURANTS_BY_REGION_CACHE_KEY_PREFIX = "discovery:kakao-restaurants:region:v3:"

# 카카오 category_name은 "음식점 > 한식 > 육류,고기"처럼 계층 전체가 온다 —
# 그 경로 안에 이 키워드가 하나라도 있으면 해당 큰 분류로 묶는다. 순서가
# 중요하다(예: "카페"가 "디저트"보다 앞서면 디저트카페가 카페로 먼저 잡힌다).
_CUISINE_KEYWORDS: list[tuple[str, str]] = [
    ("디저트", "디저트"),
    ("한식", "한식"),
    ("중식", "중식"),
    ("일식", "일식"),
    ("양식", "양식"),
    ("카페", "디저트"),
]


def _bucket_cuisine(category_path: str) -> str:
    for keyword, cuisine in _CUISINE_KEYWORDS:
        if keyword in category_path:
            return cuisine
    return "기타"
# "내 주변"은 실제로 걸어갈 수 있는 거리를 우선한다 — 1.2km(도보 15분 안팎)부터
# 시작해서, 그 반경에 너무 적으면(콜드스팟 등) 점점 넓혀서 빈 화면을 피한다.
_KAKAO_NEARBY_RADII_M = [1200, 2500, 5000]
_KAKAO_NEARBY_MIN_RESULTS = 5

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
        google_places_service: GooglePlacesService | None = None,
    ) -> None:
        self._tour_api_service = tour_api_service or TourApiService()
        self._kakao_local_service = kakao_local_service or KakaoLocalService()
        self._google_places_service = google_places_service or GooglePlacesService()

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

    async def _photo_with_fallback(self, name: str, region: str, image_url: str | None) -> dict:
        """TourAPI 사진이 없으면 구글 플레이스로 마지막 보강 — 소규모 식당·일부
        관광지는 TourAPI에 대표사진이 아예 없는 경우가 많다. 구글 사진은 이용약관상
        출처 표기가 필수라 attribution도 같이 담아 반환한다(TourAPI 사진은 불필요)."""
        if image_url is not None:
            return {"image_url": image_url, "attribution_name": None, "attribution_url": None}
        photo = await self._google_places_service.find_photo(name, region)
        return photo or {"image_url": None, "attribution_name": None, "attribution_url": None}

    async def _build_top_attractions(self) -> list[TopAttractionResponse]:
        results = await asyncio.gather(
            *(self._tour_api_service.search_attractions(keyword, 1) for keyword in _TOP_ATTRACTION_KEYWORDS)
        )

        picked = [(rank, locations[0]) for rank, locations in enumerate(results, start=1) if locations]
        photos = await asyncio.gather(
            *(self._photo_with_fallback(location.name, location.region, location.image_url) for _, location in picked)
        )

        attractions = [
            TopAttractionResponse(
                rank=rank, id=location.id, name=location.name, region=location.region,
                image_url=photo["image_url"], photo_attribution_name=photo["attribution_name"],
                photo_attribution_url=photo["attribution_url"],
            )
            for (rank, location), photo in zip(picked, photos, strict=True)
        ]

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

    async def _to_restaurant_items(self, locations: list[LocationResponse]) -> list[RestaurantItemResponse]:
        """TourAPI 대표사진이 없는 식당도 구글 플레이스로 보강해서 최대한 살린다 —
        사진 없다고 그냥 빼면 후보 풀이 크게 줄어든다(식당류는 TourAPI 사진 커버율이
        특히 낮다)."""
        photos = await asyncio.gather(
            *(self._photo_with_fallback(location.name, location.region, location.image_url) for location in locations)
        )
        return [
            RestaurantItemResponse(
                id=location.id, name=location.name, region=location.region,
                image_url=photo["image_url"], photo_attribution_name=photo["attribution_name"],
                photo_attribution_url=photo["attribution_url"],
            )
            for location, photo in zip(locations, photos, strict=True)
            if photo["image_url"] is not None
        ]

    async def _build_restaurant_categories(self) -> list[RestaurantCategoryResponse]:
        results = await asyncio.gather(
            *(
                self._tour_api_service.search_restaurants(keyword, _RESTAURANTS_PER_CATEGORY)
                for keyword in _RESTAURANT_CATEGORIES.values()
            )
        )

        categories: list[RestaurantCategoryResponse] = []
        for category, locations in zip(_RESTAURANT_CATEGORIES.keys(), results, strict=True):
            items = await self._to_restaurant_items(locations)
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

        cache_key = f"discovery:restaurants:v3:{category}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [RestaurantItemResponse.model_validate(item) for item in json.loads(cached)]

        locations = await self._tour_api_service.search_restaurants(keyword, _RESTAURANT_LIST_SIZE)
        items = await self._to_restaurant_items(locations)
        await cache_set(cache_key, json.dumps([item.model_dump() for item in items]), ex=_CACHE_TTL_SECONDS)
        return items

    async def get_kakao_restaurants_nationwide(self) -> list[KakaoRestaurantResponse]:
        """카카오맵 기반 "전국" 맛집 카드 — 주요 도시 중심 좌표를 돌며 모은 풀을
        하루 단위로 캐싱한다.

        카카오 로컬 API엔 평점/리뷰 수가 없어 "리뷰 많은 순"은 낼 수 없다 — 대신
        카카오 자체 관련도 랭킹(`sort=accuracy`)을 쓴다. 사진도 카카오엔 없어서,
        같은 이름으로 TourAPI에 등록된 곳이 있으면 그 사진으로 보강한다(없으면
        프론트엔드가 아이콘 배지로 폴백).
        """
        cached = await cache_get(_KAKAO_RESTAURANTS_CACHE_KEY)
        if cached is not None:
            return [KakaoRestaurantResponse.model_validate(item) for item in json.loads(cached)]

        results = await asyncio.gather(
            *(
                self._kakao_local_service.search_restaurants(
                    latitude=lat, longitude=lng, limit=_KAKAO_RESTAURANTS_PER_CITY, sort="accuracy"
                )
                for lat, lng in _MAJOR_CITY_COORDS.values()
            )
        )
        places = [place for places in results for place in places if place.get("id")]
        restaurants = await self._to_responses(places)
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
        """카카오맵 기반 "내 주변" 맛집 — 위치에 따라 매번 달라지므로 캐싱하지 않는다.

        도보로 갈 만한 거리(1.2km)부터 찾고, 그 반경에 결과가 너무 적으면(콜드
        스팟 등) 점점 넓혀서 빈 화면을 피한다. 거리순 정렬 자체가 "가까운
        곳부터"라 리뷰 수 없이도 실질적인 우선순위가 된다.
        """
        places: list[dict] = []
        for radius_m in _KAKAO_NEARBY_RADII_M:
            places = await self._kakao_local_service.search_restaurants(
                latitude=latitude, longitude=longitude, radius_m=radius_m, limit=15, sort="distance"
            )
            if len(places) >= _KAKAO_NEARBY_MIN_RESULTS:
                break

        return await self._to_responses([p for p in places if p.get("id")])

    async def _to_responses(self, places: list[dict]) -> list[KakaoRestaurantResponse]:
        """카카오 검색 결과에 같은 이름의 TourAPI 등록 사진이 있으면 보강하고,
        없으면(식당류는 특히 자주 없다) 구글 플레이스로 한 번 더 보강해 응답으로 바꾼다.
        구글 사진은 이용약관상 출처 표기가 필수라 attribution도 같이 담는다."""
        async def photo_for(place: dict) -> dict:
            image_url = await self._tour_api_service.find_image_url(place["name"])
            if image_url is not None:
                return {"image_url": image_url, "attribution_name": None, "attribution_url": None}
            region = extract_city(place.get("address", ""))
            photo = await self._google_places_service.find_photo(place["name"], region)
            return photo or {"image_url": None, "attribution_name": None, "attribution_url": None}

        photos = await asyncio.gather(*(photo_for(place) for place in places))
        return [
            KakaoRestaurantResponse(
                id=place["id"],
                name=place["name"],
                category=place["category"],
                cuisine=_bucket_cuisine(place.get("category_path", "")),
                address=place["address"],
                distance_m=place.get("distance_m"),
                image_url=photo["image_url"],
                photo_attribution_name=photo["attribution_name"],
                photo_attribution_url=photo["attribution_url"],
                phone=place.get("phone"),
                place_url=place.get("place_url"),
                latitude=place.get("latitude"),
                longitude=place.get("longitude"),
            )
            for place, photo in zip(places, photos, strict=True)
        ]

    async def get_kakao_restaurants_by_region(self, region: str) -> list[KakaoRestaurantResponse]:
        """지역 캐러셀용 — 음식점(FD6)+카페(CE7)를 한 번에 모아서 반환하고,
        각 항목에 큰 분류(cuisine)를 붙여둔다. 카테고리 토글은 이 한 번의
        응답을 프론트에서 그대로 필터링해서 쓴다(토글마다 다시 조회하지 않는다).
        """
        coords = _REGION_COORDS.get(region)
        if coords is None:
            return []

        cache_key = f"{_KAKAO_RESTAURANTS_BY_REGION_CACHE_KEY_PREFIX}{region}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [KakaoRestaurantResponse.model_validate(item) for item in json.loads(cached)]

        lat, lng = coords
        food, cafe = await asyncio.gather(
            self._kakao_local_service.search_restaurants(
                latitude=lat, longitude=lng, radius_m=8000, limit=15, sort="accuracy", category_group_code="FD6"
            ),
            self._kakao_local_service.search_restaurants(
                latitude=lat, longitude=lng, radius_m=8000, limit=15, sort="accuracy", category_group_code="CE7"
            ),
        )
        seen: set[str] = set()
        places: list[dict] = []
        for place in [*food, *cafe]:
            if not place.get("id") or place["id"] in seen:
                continue
            seen.add(place["id"])
            places.append(place)

        restaurants = await self._to_responses(places)
        await cache_set(
            cache_key,
            json.dumps([item.model_dump() for item in restaurants]),
            ex=_CACHE_TTL_SECONDS,
        )
        return restaurants

    async def get_popular_locations(
        self, db: AsyncSession, *, limit: int = 10
    ) -> list[PopularLocationResponse]:
        """둘러보기 탭 "다른 사람들이 둘러본 골목" — 실제로 찜(저장)한 사용자 수 기준.

        큐레이션 3곳으로만 채워지던 예전 방식 대신, 실제 사용자 행동(saved_locations)을
        집계한다. 아직 아무도 안 찜한 콜드 스타트 상태면 빈 리스트를 반환하고,
        프론트엔드가 큐레이션 목록으로 폴백한다(get_all_locations).
        """
        rows = await db.execute(
            select(SavedLocation.location_id, func.count().label("count"))
            .group_by(SavedLocation.location_id)
            .order_by(desc("count"))
            .limit(limit)
        )
        counts = rows.all()
        if not counts:
            return []

        locations = await asyncio.gather(
            *(self._tour_api_service.get_location_by_id(location_id) for location_id, _ in counts)
        )
        return [
            PopularLocationResponse(**location.model_dump(), saved_by_count=count)
            for (_, count), location in zip(counts, locations, strict=True)
            if location is not None
        ]
