from fastapi import APIRouter

from ...models.discovery import RestaurantCategoryResponse, RestaurantItemResponse, TopAttractionResponse
from ...services.discovery import DiscoveryService

router = APIRouter(prefix="/api/discovery", tags=["discovery"])
_discovery_service = DiscoveryService()


@router.get("/top-attractions", response_model=list[TopAttractionResponse])
async def get_top_attractions() -> list[TopAttractionResponse]:
    return await _discovery_service.get_top_attractions()


@router.get("/restaurant-categories", response_model=list[RestaurantCategoryResponse])
async def get_restaurant_categories() -> list[RestaurantCategoryResponse]:
    return await _discovery_service.get_restaurant_categories()


@router.get("/restaurants", response_model=list[RestaurantItemResponse])
async def get_restaurants_by_category(category: str) -> list[RestaurantItemResponse]:
    return await _discovery_service.get_restaurants_by_category(category)


@router.get("/restaurants/nearby", response_model=list[RestaurantItemResponse])
async def get_restaurants_nearby(lat: float, lng: float) -> list[RestaurantItemResponse]:
    return await _discovery_service.get_restaurants_nearby(latitude=lat, longitude=lng)
