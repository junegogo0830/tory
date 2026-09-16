from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.postgres import get_db_session
from ...models.discovery import (
    KakaoRestaurantResponse,
    RestaurantCategoryResponse,
    RestaurantItemResponse,
    TopAttractionResponse,
)
from ...models.location import PopularLocationResponse
from ...services.discovery import DiscoveryService

router = APIRouter(prefix="/api/discovery", tags=["discovery"])
_discovery_service = DiscoveryService()


@router.get("/popular-locations", response_model=list[PopularLocationResponse])
async def get_popular_locations(
    limit: int = Query(10, ge=1, le=30), db: AsyncSession = Depends(get_db_session)
) -> list[PopularLocationResponse]:
    return await _discovery_service.get_popular_locations(db, limit=limit)


@router.get("/top-attractions", response_model=list[TopAttractionResponse])
async def get_top_attractions() -> list[TopAttractionResponse]:
    return await _discovery_service.get_top_attractions()


@router.get("/restaurant-categories", response_model=list[RestaurantCategoryResponse])
async def get_restaurant_categories() -> list[RestaurantCategoryResponse]:
    return await _discovery_service.get_restaurant_categories()


@router.get("/restaurants", response_model=list[RestaurantItemResponse])
async def get_restaurants_by_category(category: str) -> list[RestaurantItemResponse]:
    return await _discovery_service.get_restaurants_by_category(category)


@router.get("/kakao-restaurants", response_model=list[KakaoRestaurantResponse])
async def get_kakao_restaurants_nationwide() -> list[KakaoRestaurantResponse]:
    return await _discovery_service.get_kakao_restaurants_nationwide()


@router.get("/kakao-restaurants/nearby", response_model=list[KakaoRestaurantResponse])
async def get_kakao_restaurants_nearby(lat: float, lng: float) -> list[KakaoRestaurantResponse]:
    return await _discovery_service.get_kakao_restaurants_nearby(latitude=lat, longitude=lng)


@router.get("/kakao-restaurants/by-region", response_model=list[KakaoRestaurantResponse])
async def get_kakao_restaurants_by_region(region: str) -> list[KakaoRestaurantResponse]:
    """지역 캐러셀용 — 음식점+카페를 한 번에 모아 각 항목에 큰 분류(cuisine)를
    붙여 반환한다. 카테고리 토글은 프론트에서 이 응답을 그대로 필터링한다."""
    return await _discovery_service.get_kakao_restaurants_by_region(region)
