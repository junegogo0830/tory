import logging

import httpx

from ..core.config import settings
from ..db.redis import cache_get, cache_set
from ..models.weather import WeatherResponse

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 900  # 날씨는 자주 바뀌므로 15분만 캐싱.
_BASE_URL = "https://api.openweathermap.org/data/2.5/weather"

_RAIN_MAIN = {"Rain", "Drizzle", "Thunderstorm"}
_OVERCAST_MAIN = {"Mist", "Fog", "Haze", "Smoke", "Dust", "Ash", "Squall", "Tornado"}


class WeatherService:
    """OpenWeatherMap으로 현재 날씨를 조회해 홈 화면 애니메이션/인사말용 조건으로 단순화한다.

    OPENWEATHER_API_KEY가 없으면 항상 None — 프론트가 날씨 무관 기본 인사말/정적
    배경으로 폴백한다.
    """

    async def get_current_weather(self, latitude: float, longitude: float) -> WeatherResponse | None:
        if not settings.openweather_api_key:
            return None

        # 소수점 2자리(약 1km 격자)로 반올림해 캐시 적중률을 높인다 — 날씨는
        # 그 정도 오차는 무의미하다.
        cache_key = f"weather:{latitude:.2f},{longitude:.2f}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return WeatherResponse.model_validate_json(cached) if cached != "null" else None

        weather = await self._fetch(latitude, longitude)
        await cache_set(
            cache_key, weather.model_dump_json() if weather else "null", ex=_CACHE_TTL_SECONDS
        )
        return weather

    async def _fetch(self, latitude: float, longitude: float) -> WeatherResponse | None:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(
                    _BASE_URL,
                    params={
                        "lat": latitude,
                        "lon": longitude,
                        "appid": settings.openweather_api_key,
                        "units": "metric",
                        "lang": "kr",
                    },
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            logger.exception("OpenWeatherMap fetch failed for lat=%s lng=%s", latitude, longitude)
            return None

        try:
            weather_item = body["weather"][0]
            main = weather_item["main"]
            icon = weather_item.get("icon", "")
            is_daytime = not icon.endswith("n")
            temperature = float(body["main"]["temp"])
            description = str(weather_item.get("description") or main)
        except (KeyError, IndexError, TypeError, ValueError):
            logger.warning("Unexpected OpenWeatherMap response shape: %r", body)
            return None

        condition = self._condition_for(main, body.get("clouds", {}).get("all", 0), is_daytime)
        return WeatherResponse(
            condition=condition, temperature=temperature, description=description, is_daytime=is_daytime
        )

    @staticmethod
    def _condition_for(main: str, cloud_cover_pct: float, is_daytime: bool) -> str:
        """모든 날씨를 낮/밤으로 나눈다 — "비 오는 아침"과 "비 오는 밤"은 다른
        애니메이션이어야 한다는 피드백으로, clear만 낮/밤이 있던 걸 전부(비/눈/
        구름많음/흐림)로 넓혔다.
        """
        suffix = "day" if is_daytime else "night"

        if main in _RAIN_MAIN:
            base = "rain"
        elif main == "Snow":
            base = "snow"
        elif main == "Clear":
            base = "clear"
        elif main == "Clouds":
            base = "cloudy" if cloud_cover_pct < 50 else "overcast"
        else:
            base = "overcast"

        return f"{base}_{suffix}"
