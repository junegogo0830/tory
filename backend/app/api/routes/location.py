from fastapi import APIRouter, HTTPException, Query

from ...models.location import LocationResponse
from ...services.tourapi import TourApiService

router = APIRouter(prefix="/api/location", tags=["location"])
_tour_api_service = TourApiService()


@router.get("", response_model=LocationResponse)
async def resolve_location(query: str = Query(..., min_length=1)) -> LocationResponse:
    """자유 입력(주소/학교/아파트)에 대응하는 장소를 반환한다.

    TOUR_API_KEY가 없으면 목 데이터로 응답한다.
    """
    return await _tour_api_service.resolve_location(query)


@router.get("/{location_id}", response_model=LocationResponse)
async def get_location(location_id: str) -> LocationResponse:
    location = await _tour_api_service.get_location_by_id(location_id)
    if location is None:
        raise HTTPException(status_code=404, detail="Location not found")
    return location
