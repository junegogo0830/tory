import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.kakao_local import KakaoLocalService

client = TestClient(app)


def test_roadview_unknown_location_returns_404() -> None:
    response = client.get("/roadview/does-not-exist")
    assert response.status_code == 404


def test_roadview_shows_fallback_message_when_geocode_fails() -> None:
    # conftest의 autouse fixture가 geocode를 항상 None으로 만든다.
    response = client.get("/roadview/suncheon-jeonpo")
    assert response.status_code == 200
    assert "위치를 찾지 못했어요" in response.text


def test_roadview_renders_map_sdk_when_geocode_succeeds(monkeypatch: pytest.MonkeyPatch) -> None:
    async def _fake_geocode(self: KakaoLocalService, query: str) -> tuple[float, float]:  # noqa: ARG001
        return (34.9506, 127.4989)

    monkeypatch.setattr(KakaoLocalService, "geocode", _fake_geocode)

    response = client.get("/roadview/suncheon-jeonpo")
    assert response.status_code == 200
    assert "kakao.maps.Roadview" in response.text
    assert "34.9506" in response.text
    assert "127.4989" in response.text
