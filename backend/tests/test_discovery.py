from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_top_attractions_returns_empty_list_when_tourapi_key_missing() -> None:
    # conftest가 _search_from_tourapi를 항상 []로 만든다.
    response = client.get("/api/discovery/top-attractions")
    assert response.status_code == 200
    assert response.json() == []


def test_top_attractions_returns_ranked_list(monkeypatch) -> None:
    from app.models.location import LocationResponse
    from app.services.tourapi import TourApiService

    async def _fake_search(self: TourApiService, query: str, num_rows: int, *, content_type_id: str = "12"):  # noqa: ARG001
        return [
            LocationResponse(
                id=f"tour-{query}", name=query, region=f"{query}시",
                description="d", past_year=2026, current_year=2026, source="tourapi",
                image_url=f"http://example.com/{query}.jpg",
            )
        ]

    monkeypatch.setattr(TourApiService, "_search_from_tourapi", _fake_search)

    response = client.get("/api/discovery/top-attractions")
    assert response.status_code == 200
    body = response.json()
    from app.services.discovery import _TOP_ATTRACTION_KEYWORDS

    assert len(body) == len(_TOP_ATTRACTION_KEYWORDS)
    assert [item["rank"] for item in body] == list(range(1, len(_TOP_ATTRACTION_KEYWORDS) + 1))


def test_top_attractions_pool_is_cached_after_first_build(monkeypatch) -> None:
    from app.models.location import LocationResponse
    from app.services.tourapi import TourApiService

    calls = 0

    async def _fake_search(self: TourApiService, query: str, num_rows: int, *, content_type_id: str = "12"):  # noqa: ARG001
        nonlocal calls
        calls += 1
        return [
            LocationResponse(
                id=f"tour-{query}", name=query, region=f"{query}시",
                description="d", past_year=2026, current_year=2026, source="tourapi",
                image_url=f"http://example.com/{query}.jpg",
            )
        ]

    monkeypatch.setattr(TourApiService, "_search_from_tourapi", _fake_search)

    client.get("/api/discovery/top-attractions")
    client.get("/api/discovery/top-attractions")
    from app.services.discovery import _TOP_ATTRACTION_KEYWORDS

    assert calls == len(_TOP_ATTRACTION_KEYWORDS)


def test_restaurant_categories_returns_empty_list_when_tourapi_key_missing() -> None:
    response = client.get("/api/discovery/restaurant-categories")
    assert response.status_code == 200
    assert response.json() == []


def test_restaurant_categories_groups_by_category(monkeypatch) -> None:
    from app.models.location import LocationResponse
    from app.services.tourapi import TourApiService

    async def _fake_search(self: TourApiService, query: str, num_rows: int, *, content_type_id: str = "12"):  # noqa: ARG001
        return [
            LocationResponse(
                id=f"tour-{query}-{i}", name=f"{query} {i}", region="서울시",
                description="d", past_year=2026, current_year=2026, source="tourapi",
                image_url=f"http://example.com/{query}-{i}.jpg",
            )
            for i in range(2)
        ]

    monkeypatch.setattr(TourApiService, "_search_from_tourapi", _fake_search)

    response = client.get("/api/discovery/restaurant-categories")
    assert response.status_code == 200
    body = response.json()
    from app.services.discovery import _RESTAURANT_CATEGORIES

    assert len(body) == len(_RESTAURANT_CATEGORIES)
    assert {category["category"] for category in body} == set(_RESTAURANT_CATEGORIES.keys())
    assert all(category["items"] for category in body)


def test_restaurants_by_category_rejects_unknown_category() -> None:
    response = client.get("/api/discovery/restaurants", params={"category": "존재안함"})
    assert response.status_code == 200
    assert response.json() == []


def test_restaurants_by_category_returns_items(monkeypatch) -> None:
    from app.models.location import LocationResponse
    from app.services.tourapi import TourApiService

    async def _fake_search(self: TourApiService, query: str, num_rows: int, *, content_type_id: str = "12"):  # noqa: ARG001
        return [
            LocationResponse(
                id=f"tour-{query}-{i}", name=f"{query} {i}", region="서울시",
                description="d", past_year=2026, current_year=2026, source="tourapi",
                image_url=f"http://example.com/{query}-{i}.jpg",
            )
            for i in range(3)
        ]

    monkeypatch.setattr(TourApiService, "_search_from_tourapi", _fake_search)

    response = client.get("/api/discovery/restaurants", params={"category": "한식"})
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 3
    assert all(item["image_url"] for item in body)


def test_kakao_restaurants_nationwide_returns_empty_list_when_kakao_key_missing() -> None:
    # conftest가 KakaoLocalService.search_restaurants를 항상 []로 만든다.
    response = client.get("/api/discovery/kakao-restaurants")
    assert response.status_code == 200
    assert response.json() == []


def test_kakao_restaurants_nationwide_pools_major_cities(monkeypatch) -> None:
    from app.services.kakao_local import KakaoLocalService

    async def _fake_search(self: KakaoLocalService, *, latitude: float, longitude: float, **kwargs):  # noqa: ARG001
        return [
            {
                "id": f"kakao-{latitude}-{i}",
                "name": f"식당{i}",
                "category": "한식",
                "address": "어딘가",
                "distance_m": None,
                "latitude": latitude,
                "longitude": longitude,
            }
            for i in range(2)
        ]

    monkeypatch.setattr(KakaoLocalService, "search_restaurants", _fake_search)

    response = client.get("/api/discovery/kakao-restaurants")
    assert response.status_code == 200
    body = response.json()
    from app.services.discovery import _MAJOR_CITY_COORDS

    assert len(body) == len(_MAJOR_CITY_COORDS) * 2
    assert all("image_url" not in item for item in body)


def test_kakao_restaurants_nearby_returns_items(monkeypatch) -> None:
    from app.services.kakao_local import KakaoLocalService

    async def _fake_nearby(self: KakaoLocalService, **kwargs):  # noqa: ARG001
        return [
            {
                "id": "kakao-1", "name": "주변 식당", "category": "한식",
                "address": "경기 수원시", "distance_m": 350, "latitude": 37.29, "longitude": 127.06,
            }
        ]

    monkeypatch.setattr(KakaoLocalService, "search_restaurants", _fake_nearby)

    response = client.get("/api/discovery/kakao-restaurants/nearby", params={"lat": 37.29, "lng": 127.06})
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["name"] == "주변 식당"
    assert body[0]["distance_m"] == 350
