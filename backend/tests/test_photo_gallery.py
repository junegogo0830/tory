import httpx
import pytest

from app.core.config import settings
from app.services.photo_gallery import PhotoGalleryService


@pytest.mark.asyncio
async def test_search_photos_returns_empty_without_any_key(monkeypatch):
    monkeypatch.setattr(settings, "tour_photo_api_key", "")
    monkeypatch.setattr(settings, "tour_api_key", "")
    service = PhotoGalleryService()
    assert await service.search_photos("순천") == []


@pytest.mark.asyncio
async def test_search_photos_falls_back_to_tour_api_key(monkeypatch):
    monkeypatch.setattr(settings, "tour_photo_api_key", "")
    monkeypatch.setattr(settings, "tour_api_key", "shared-key")
    service = PhotoGalleryService()
    assert service._service_key() == "shared-key"


@pytest.mark.asyncio
async def test_search_photos_parses_gallery_items_and_drops_photoless_entries(monkeypatch):
    monkeypatch.setattr(settings, "tour_photo_api_key", "test-key")

    def handler(request: httpx.Request) -> httpx.Response:
        assert "gallerySearchList1" in str(request.url)
        assert "keyword=" in str(request.url)
        return httpx.Response(
            200,
            json={
                "response": {
                    "body": {
                        "items": {
                            "item": [
                                {
                                    "galTitle": "순천만습지",
                                    "galWebImageUrl": "https://img/suncheon.jpg",
                                    "galPhotographyLocation": "전남 순천시",
                                },
                                # 이미지가 없는 항목은 후보에서 제외돼야 한다.
                                {"galTitle": "사진없음", "galWebImageUrl": "", "galPhotographyLocation": ""},
                            ]
                        }
                    }
                }
            },
        )

    original = httpx.AsyncClient
    monkeypatch.setattr(
        "app.services.photo_gallery.httpx.AsyncClient",
        lambda **kwargs: original(transport=httpx.MockTransport(handler), **kwargs),
    )

    service = PhotoGalleryService()
    results = await service.search_photos("순천", num_rows=10)

    assert len(results) == 1
    assert results[0]["title"] == "순천만습지"
    assert results[0]["image_url"] == "https://img/suncheon.jpg"


@pytest.mark.asyncio
async def test_search_photos_returns_empty_on_http_error(monkeypatch):
    monkeypatch.setattr(settings, "tour_photo_api_key", "test-key")

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500)

    original = httpx.AsyncClient
    monkeypatch.setattr(
        "app.services.photo_gallery.httpx.AsyncClient",
        lambda **kwargs: original(transport=httpx.MockTransport(handler), **kwargs),
    )

    service = PhotoGalleryService()
    assert await service.search_photos("아무데나") == []
