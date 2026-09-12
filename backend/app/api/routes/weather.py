from fastapi import APIRouter

from ...models.weather import WeatherResponse
from ...services.weather import WeatherService

router = APIRouter(prefix="/api/weather", tags=["weather"])
_weather_service = WeatherService()


@router.get("/current", response_model=WeatherResponse | None)
async def get_current_weather(lat: float, lng: float) -> WeatherResponse | None:
    """현재 날씨. 키가 없거나 조회 실패 시 null — 프론트가 날씨 무관 기본값으로 폴백한다."""
    return await _weather_service.get_current_weather(lat, lng)
