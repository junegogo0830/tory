import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.location import LocationResponse
from app.services.kakao_local import KakaoLocalService
from app.services.tourapi import TourApiService

client = TestClient(app)


def _location_without_coords() -> LocationResponse:
    # 큐레이션 3곳(순천/군산/영월)은 이제 전부 좌표가 미리 채워져 있어(로드뷰
    # 지오코딩 재시도 없이 바로 씀) 이 라우트의 geocode 폴백 분기를 타지 않는다
    # — 좌표 없는 장소(예: 매칭 안 된 TourAPI 상세)를 흉내내야 그 분기를 검증할 수 있다.
    return LocationResponse(
        id="tour-no-coords", name="테스트동", region="테스트시",
        description="", past_year=2026, current_year=2026,
        latitude=None, longitude=None,
    )


def test_roadview_unknown_location_returns_404() -> None:
    response = client.get("/roadview/does-not-exist")
    assert response.status_code == 404


def test_roadview_shows_fallback_message_when_geocode_fails(monkeypatch: pytest.MonkeyPatch) -> None:
    async def _fake_get_location_by_id(self: TourApiService, location_id: str) -> LocationResponse:  # noqa: ARG001
        return _location_without_coords()

    monkeypatch.setattr(TourApiService, "get_location_by_id", _fake_get_location_by_id)
    # conftest의 autouse fixture가 geocode를 항상 None으로 만든다.
    response = client.get("/roadview/tour-no-coords")
    assert response.status_code == 200
    assert "위치를 찾지 못했어요" in response.text


def test_roadview_renders_map_sdk_when_geocode_succeeds(monkeypatch: pytest.MonkeyPatch) -> None:
    async def _fake_get_location_by_id(self: TourApiService, location_id: str) -> LocationResponse:  # noqa: ARG001
        return _location_without_coords()
    async def _fake_geocode(self: KakaoLocalService, query: str) -> tuple[float, float]:  # noqa: ARG001
        return (34.9506, 127.4989)

    monkeypatch.setattr(TourApiService, "get_location_by_id", _fake_get_location_by_id)
    monkeypatch.setattr(KakaoLocalService, "geocode", _fake_geocode)

    response = client.get("/roadview/tour-no-coords")
    assert response.status_code == 200
    assert "kakao.maps.Roadview" in response.text
    assert "34.9506" in response.text
    assert "127.4989" in response.text
