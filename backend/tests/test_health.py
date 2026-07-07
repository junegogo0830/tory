from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_location_stub_returns_mock_when_no_api_key() -> None:
    response = client.get("/api/location", params={"query": "전라남도 순천시"})
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == "suncheon-jeonpo"
    assert body["source"] == "mock"


def test_archive_returns_empty_list_for_cold_spot() -> None:
    response = client.get("/api/archive/yeongwol-jang")
    assert response.status_code == 200
    assert response.json() == []
