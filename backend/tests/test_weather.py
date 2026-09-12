from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_current_weather_is_null_when_api_key_missing() -> None:
    # conftest가 _fetch를 항상 None으로 만든다(OPENWEATHER_API_KEY 유무와 무관하게).
    response = client.get("/api/weather/current", params={"lat": 37.29, "lng": 127.06})
    assert response.status_code == 200
    assert response.json() is None


def test_current_weather_returns_generated_response(monkeypatch) -> None:
    from app.core.config import settings
    from app.models.weather import WeatherResponse
    from app.services.weather import WeatherService

    async def _fake_fetch(self: WeatherService, latitude: float, longitude: float):  # noqa: ARG001
        return WeatherResponse(condition="rain", temperature=18.5, description="비", is_daytime=True)

    monkeypatch.setattr(settings, "openweather_api_key", "fake-key-for-test")
    monkeypatch.setattr(WeatherService, "_fetch", _fake_fetch)

    response = client.get("/api/weather/current", params={"lat": 37.29, "lng": 127.06})
    assert response.status_code == 200
    body = response.json()
    assert body["condition"] == "rain"
    assert body["temperature"] == 18.5


def test_current_weather_is_cached_after_first_call(monkeypatch) -> None:
    from app.core.config import settings
    from app.models.weather import WeatherResponse
    from app.services.weather import WeatherService

    calls = 0

    async def _fake_fetch(self: WeatherService, latitude: float, longitude: float):  # noqa: ARG001
        nonlocal calls
        calls += 1
        return WeatherResponse(condition="clear_day", temperature=20.0, description="맑음", is_daytime=True)

    monkeypatch.setattr(settings, "openweather_api_key", "fake-key-for-test")
    monkeypatch.setattr(WeatherService, "_fetch", _fake_fetch)

    first = client.get("/api/weather/current", params={"lat": 35.1, "lng": 129.0})
    second = client.get("/api/weather/current", params={"lat": 35.1, "lng": 129.0})
    assert first.json() == second.json()
    assert calls == 1


def test_condition_mapping_covers_rain_snow_clear_cloudy() -> None:
    from app.services.weather import WeatherService

    svc = WeatherService()
    # 모든 조건이 낮/밤으로 나뉜다 — "비 오는 아침"과 "비 오는 밤"은 다른 애니메이션.
    assert svc._condition_for("Rain", 0, True) == "rain_day"
    assert svc._condition_for("Rain", 0, False) == "rain_night"
    assert svc._condition_for("Thunderstorm", 0, True) == "rain_day"
    assert svc._condition_for("Snow", 0, True) == "snow_day"
    assert svc._condition_for("Snow", 0, False) == "snow_night"
    assert svc._condition_for("Clear", 0, True) == "clear_day"
    assert svc._condition_for("Clear", 0, False) == "clear_night"
    assert svc._condition_for("Clouds", 20, True) == "cloudy_day"
    assert svc._condition_for("Clouds", 20, False) == "cloudy_night"
    assert svc._condition_for("Clouds", 80, True) == "overcast_day"
    assert svc._condition_for("Mist", 0, True) == "overcast_day"
