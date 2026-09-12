from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_highlights_returns_empty_list_when_tourapi_key_missing() -> None:
    # conftest가 _search_from_tourapi를 항상 []로 만든다.
    response = client.get("/api/highlights")
    assert response.status_code == 200
    assert response.json() == []


def test_highlights_returns_random_sample_from_pool(monkeypatch) -> None:
    from app.models.location import LocationResponse
    from app.services.tourapi import TourApiService

    async def _fake_search(self: TourApiService, query: str, num_rows: int, *, content_type_id: str = "12"):  # noqa: ARG001
        return [
            LocationResponse(
                id=f"tour-{query}-{i}", name=f"{query} 명소 {i}", region=f"{query}시",
                description="d", past_year=2026, current_year=2026, source="tourapi",
                image_url=f"http://example.com/{query}-{i}.jpg",
            )
            for i in range(4)
        ]

    monkeypatch.setattr(TourApiService, "_search_from_tourapi", _fake_search)

    response = client.get("/api/highlights")
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 10
    assert all(card["image_url"] for card in body)
    # 중복 없이 골랐는지 확인.
    assert len({card["id"] for card in body}) == 10


def test_highlights_pool_is_cached_after_first_build(monkeypatch) -> None:
    from app.models.location import LocationResponse
    from app.services.tourapi import TourApiService

    calls = 0

    async def _fake_search(self: TourApiService, query: str, num_rows: int, *, content_type_id: str = "12"):  # noqa: ARG001
        nonlocal calls
        calls += 1
        return [
            LocationResponse(
                id=f"tour-{query}-{i}", name=f"{query} 명소 {i}", region=f"{query}시",
                description="d", past_year=2026, current_year=2026, source="tourapi",
                image_url=f"http://example.com/{query}-{i}.jpg",
            )
            for i in range(4)
        ]

    monkeypatch.setattr(TourApiService, "_search_from_tourapi", _fake_search)

    client.get("/api/highlights")
    client.get("/api/highlights")
    # 풀은 시드 키워드 개수만큼만 검색하면 되고, 두 번째 요청은 캐시에서 읽어야 한다.
    from app.services.highlight import _SEED_KEYWORDS

    assert calls == len(_SEED_KEYWORDS)
