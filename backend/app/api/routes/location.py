from fastapi import APIRouter, HTTPException, Query

from ...models.location import LocationResponse
from ...models.nearby_place import NearbyPlace
from ...services.tourapi import TourApiService

router = APIRouter(prefix="/api/location", tags=["location"])
_tour_api_service = TourApiService()


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
