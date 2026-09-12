from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_nearby_map_returns_html_with_empty_places_when_tourapi_key_missing() -> None:
    # conftest가 find_nearby_places를 항상 []로 만든다.
    response = client.get("/map/nearby", params={"lat": 37.29, "lng": 127.06})
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "var places = []" in response.text


def test_nearby_map_embeds_real_places(monkeypatch) -> None:
    from app.services.tourapi import TourApiService

    async def _fake_nearby(self: TourApiService, **kwargs) -> list[dict]:  # noqa: ARG001
        return [
            {"title": "광교중앙공원", "category": "관광지", "distance_m": 120, "addr": "어딘가",
             "latitude": 37.2947, "longitude": 127.0601},
        ]

    monkeypatch.setattr(TourApiService, "find_nearby_places", _fake_nearby)

    response = client.get("/map/nearby", params={"lat": 37.2912, "lng": 127.0613})
    assert response.status_code == 200
    assert "광교중앙공원" in response.text
    assert "37.2947" in response.text
