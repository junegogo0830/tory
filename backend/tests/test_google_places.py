import httpx
import pytest

from app.core.config import settings
from app.services.google_places import GooglePlacesService, _parse_attribution

# conftest.py의 autouse fixture가 find_nearby를 항상 []로 반환하게 막아둔다
# (다른 테스트가 실제 네트워크를 안 타게 하려고) — 이 파일은 find_nearby
# 자체를 검증해야 하니, 모듈 임포트 시점(어떤 monkeypatch도 적용되기 전)의
# 진짜 구현을 미리 붙잡아뒀다가 각 테스트에서 되돌려 쓴다.
_REAL_FIND_NEARBY = GooglePlacesService.find_nearby


def test_parse_attribution_extracts_name_and_url():
    html = ['<a href="https://maps.google.com/maps/contrib/123">이혁</a>']
    result = _parse_attribution(html)
    assert result == {"attribution_url": "https://maps.google.com/maps/contrib/123", "attribution_name": "이혁"}


def test_parse_attribution_returns_none_for_empty_list():
    assert _parse_attribution([]) is None


def test_parse_attribution_returns_none_for_malformed_html():
    assert _parse_attribution(["그냥 텍스트"]) is None


@pytest.mark.asyncio
async def test_find_nearby_filters_out_disallowed_business_types(monkeypatch):
    """옷가게/은행 같은 일반 업체는 화이트리스트에 없어서 후보에서 빠져야 한다."""
    monkeypatch.setattr(settings, "google_maps_api_key", "test-key")
    monkeypatch.setattr(GooglePlacesService, "find_nearby", _REAL_FIND_NEARBY)

    def handler(request: httpx.Request) -> httpx.Response:
        if "nearbysearch" in str(request.url):
            return httpx.Response(200, json={"results": [
                {
                    "name": "관광명소", "types": ["tourist_attraction", "point_of_interest"],
                    "geometry": {"location": {"lat": 37.1, "lng": 127.1}},
                    "vicinity": "어딘가",
                    "photos": [{"photo_reference": "ref1", "html_attributions": []}],
                },
                {
                    "name": "옷가게", "types": ["clothing_store", "point_of_interest"],
                    "geometry": {"location": {"lat": 37.1, "lng": 127.1}},
                    "vicinity": "어딘가",
                    "photos": [{"photo_reference": "ref2", "html_attributions": []}],
                },
                {
                    "name": "은행", "types": ["bank", "point_of_interest"],
                    "geometry": {"location": {"lat": 37.1, "lng": 127.1}},
                    "vicinity": "어딘가",
                    "photos": [{"photo_reference": "ref3", "html_attributions": []}],
                },
            ]})
        # photo redirect resolution
        return httpx.Response(302, headers={"location": "https://lh3.googleusercontent.com/photo.jpg"})

    original = httpx.AsyncClient
    monkeypatch.setattr(
        "app.services.google_places.httpx.AsyncClient",
        lambda **kwargs: original(transport=httpx.MockTransport(handler), **kwargs),
    )

    service = GooglePlacesService()
    results = await service.find_nearby(latitude=37.1, longitude=127.1, radius_m=3000)

    assert [r["title"] for r in results] == ["관광명소"]


@pytest.mark.asyncio
async def test_find_nearby_includes_attribution_per_candidate(monkeypatch):
    monkeypatch.setattr(settings, "google_maps_api_key", "test-key")
    monkeypatch.setattr(GooglePlacesService, "find_nearby", _REAL_FIND_NEARBY)

    def handler(request: httpx.Request) -> httpx.Response:
        if "nearbysearch" in str(request.url):
            return httpx.Response(200, json={"results": [
                {
                    "name": "카페 어게인", "types": ["cafe", "point_of_interest"],
                    "geometry": {"location": {"lat": 37.1, "lng": 127.1}},
                    "vicinity": "어딘가",
                    "photos": [{
                        "photo_reference": "ref1",
                        "html_attributions": ['<a href="https://maps.google.com/maps/contrib/9">홍길동</a>'],
                    }],
                },
            ]})
        return httpx.Response(302, headers={"location": "https://lh3.googleusercontent.com/photo.jpg"})

    original = httpx.AsyncClient
    monkeypatch.setattr(
        "app.services.google_places.httpx.AsyncClient",
        lambda **kwargs: original(transport=httpx.MockTransport(handler), **kwargs),
    )

    service = GooglePlacesService()
    results = await service.find_nearby(latitude=37.1, longitude=127.1, radius_m=3000)

    assert len(results) == 1
    assert results[0]["attribution_name"] == "홍길동"
    assert results[0]["attribution_url"] == "https://maps.google.com/maps/contrib/9"
