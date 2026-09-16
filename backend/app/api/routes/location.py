from fastapi import APIRouter, HTTPException, Query

from ...models.custom_course import KakaoPlaceSearchResult
from ...models.location import LocationResponse
from ...models.nearby_place import NearbyPlace
from ...services.kakao_local import KakaoLocalService
from ...services.tourapi import TourApiService

router = APIRouter(prefix="/api/location", tags=["location"])
_tour_api_service = TourApiService()
_kakao_local_service = KakaoLocalService()


@router.get("/all", response_model=list[LocationResponse])
async def get_all_locations() -> list[LocationResponse]:
    """홈/둘러보기 화면에서 노출할 전체 장소 목록을 반환한다."""
    return await _tour_api_service.get_all_locations()


@router.get("/search", response_model=list[LocationResponse])
async def search_locations(
    query: str = Query(..., min_length=1), limit: int = Query(5, ge=1, le=10)
) -> list[LocationResponse]:
    """검색창 자동완성용: 검색어에 맞는 후보를 최대 limit개 반환한다 (결과 없으면 빈 리스트)."""
    return await _tour_api_service.search_locations(query, limit=limit)


@router.get("/tour-search", response_model=list[LocationResponse])
async def search_tour_locations(
    query: str = Query(..., min_length=1), limit: int = Query(10, ge=1, le=10)
) -> list[LocationResponse]:
    return await _tour_api_service.search_attractions(query, num_rows=limit)


@router.get("", response_model=LocationResponse)
async def resolve_location(query: str = Query(..., min_length=1)) -> LocationResponse:
    """자유 입력(주소/학교/아파트)에 대응하는 장소를 반환한다.

    큐레이션된 3곳과 매칭되면 그 데이터를, 아니면 TourAPI 실시간 검색 결과를 반환한다.
    TOUR_API_KEY가 없거나 아무것도 매칭되지 않으면 404.
    """
    location = await _tour_api_service.resolve_location(query)
    if location is None:
        raise HTTPException(status_code=404, detail="Location not found")
    return location


@router.get("/kakao-search", response_model=list[KakaoPlaceSearchResult])
async def search_kakao_places(
    query: str = Query(..., min_length=1), limit: int = Query(10, ge=1, le=15)
) -> list[KakaoPlaceSearchResult]:
    """코스 커스텀에서 "카카오맵 기반"으로 장소를 추가할 때 쓰는 자유 검색 —
    관광지로 등록된 곳만 나오는 TourAPI 검색과 달리 식당/카페 등 실제 장소
    전반이 대상이다. id가 없는 결과(키워드 검색이 실패해 순수 주소 검색으로
    폴백된 경우, KakaoLocalService._search_places_multi 참고)는 실제 "장소"가
    아니라 코스에 넣을 대상으로 부적절해 제외한다.
    """
    places = await _kakao_local_service.search_places(query, limit=limit)
    return [
        KakaoPlaceSearchResult(
            id=place["id"],
            name=place["name"],
            address=place["address"],
            latitude=place["latitude"],
            longitude=place["longitude"],
        )
        for place in places
        if place.get("id")
    ]


@router.get("/{location_id}", response_model=LocationResponse)
async def get_location(location_id: str) -> LocationResponse:
    location = await _tour_api_service.get_location_by_id(location_id)
    if location is None:
        raise HTTPException(status_code=404, detail="Location not found")
    return location


@router.get("/{location_id}/nearby-restaurants", response_model=list[NearbyPlace])
async def get_nearby_restaurants(location_id: str) -> list[NearbyPlace]:
    """이 장소 주변 실제 음식점 목록. 장소를 못 찾거나 좌표가 없으면 빈 리스트."""
    restaurants = await _tour_api_service.find_nearby_restaurants(location_id)
    return restaurants or []
