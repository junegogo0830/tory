import io

from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from app.db.models import User
from app.main import app

client = TestClient(app)

_FAKE_USER = User(id=1, kakao_id="k1", nickname="옛길이", home_region="경기 수원시 영통구")


def test_create_post_requires_auth() -> None:
    response = client.post(
        "/api/community/posts",
        data={"region": "경기 수원시 영통구", "board": "memory"},
        files={"files": ("photo.jpg", b"fake-bytes", "image/jpeg")},
    )
    assert response.status_code == 401


def test_home_region_update_requires_auth() -> None:
    response = client.patch("/api/community/home-region", json={"region": "경기 수원시 영통구"})
    assert response.status_code == 401


def test_region_by_coords_returns_null_when_kakao_unavailable() -> None:
    # conftest가 reverse_geocode를 항상 None으로 만든다.
    response = client.get("/api/community/region-by-coords", params={"lat": 37.29, "lng": 127.06})
    assert response.status_code == 200
    assert response.json() == {"region": None}


def test_create_post_rejects_non_image_content_type(monkeypatch) -> None:
    from app.services.community import CommunityService

    app.dependency_overrides[get_current_user] = lambda: _FAKE_USER
    try:
        response = client.post(
            "/api/community/posts",
            data={"region": "경기 수원시 영통구", "board": "memory"},
            files={"files": ("note.txt", b"not-an-image", "text/plain")},
        )
        assert response.status_code == 415
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_create_post_rejects_unknown_board() -> None:
    app.dependency_overrides[get_current_user] = lambda: _FAKE_USER
    try:
        response = client.post(
            "/api/community/posts",
            data={"region": "경기 수원시 영통구", "board": "not-a-real-board"},
            files={"files": ("photo.jpg", b"fake-bytes", "image/jpeg")},
        )
        assert response.status_code == 400
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_list_posts_rejects_unknown_board() -> None:
    response = client.get(
        "/api/community/posts", params={"region": "경기 수원시 영통구", "board": "not-a-real-board"}
    )
    assert response.status_code == 400


def test_create_post_uses_community_service(monkeypatch) -> None:
    from app.models.community import CommunityPostResponse
    from app.services.community import CommunityService

    captured: dict = {}

    async def _fake_create_post(self: CommunityService, db, user, **kwargs):  # noqa: ANN001, ARG001
        captured.update(kwargs)
        return CommunityPostResponse(
            id=1,
            author_id=user.id,
            author_nickname=user.nickname,
            region=kwargs["region"],
            board=kwargs["board"],
            title=kwargs.get("title"),
            location_id=kwargs.get("location_id"),
            photo_url="/uploads/community/fake.jpg",
            caption=kwargs.get("caption"),
            memory_year=kwargs.get("memory_year"),
            created_at="2026-09-11T00:00:00+00:00",
        )

    monkeypatch.setattr(CommunityService, "create_post", _fake_create_post)
    app.dependency_overrides[get_current_user] = lambda: _FAKE_USER
    try:
        response = client.post(
            "/api/community/posts",
            data={
                "region": "경기 수원시 영통구",
                "board": "memory",
                "caption": "그 시절 우리 동네",
                "memory_year": "1998",
            },
            files={"files": ("photo.jpg", io.BytesIO(b"fake-bytes").read(), "image/jpeg")},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["author_nickname"] == "옛길이"
        assert body["caption"] == "그 시절 우리 동네"
        assert captured["region"] == "경기 수원시 영통구"
        assert captured["board"] == "memory"
        assert captured["memory_year"] == 1998
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_list_posts_uses_community_service(monkeypatch) -> None:
    from app.models.community import CommunityPostResponse
    from app.services.community import CommunityService

    async def _fake_list_posts(self: CommunityService, db, *, region, board, limit=20, offset=0, viewer_id=None, query=""):  # noqa: ANN001, ARG001
        return [
            CommunityPostResponse(
                id=1,
                author_id=1,
                author_nickname="옛길이",
                region=region,
                board=board,
                location_id=None,
                photo_url="/uploads/community/fake.jpg",
                caption=None,
                memory_year=1998,
                created_at="2026-09-11T00:00:00+00:00",
            )
        ]

    monkeypatch.setattr(CommunityService, "list_posts", _fake_list_posts)

    response = client.get(
        "/api/community/posts", params={"region": "경기 수원시 영통구", "board": "memory"}
    )
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["region"] == "경기 수원시 영통구"
    assert body[0]["board"] == "memory"
