"""장소별 추억 타임라인 / 모교 커뮤니티(동창찾기) / 타임캡슐 편지 — 새 3개 기능.

DB 없이 도는 단위/라우트 테스트만 둔다. 실제 Postgres가 필요한 CRUD 흐름은
test_community_detail.py 스타일(RUN_DB_TESTS=1)로 별도 커버하는 게 이 저장소의
기존 관례라, 여기서는 그 패턴을 새로 만들지 않고 서비스 순수 로직 + 라우트
위임만 검증한다.
"""

import datetime

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_current_user
from app.db.models import CommunityPost, User
from app.main import app
from app.services.community import CommunityService

client = TestClient(app)

_FAKE_USER = User(id=1, kakao_id="k1", nickname="옛길이", home_region="경기 수원시 영통구")


# -- 타임캡슐: 서비스 순수 로직(_to_response 마스킹) ---------------------------


def _make_post(**overrides) -> CommunityPost:
    defaults = dict(
        id=1,
        user_id=1,
        region="경기 수원시 영통구",
        board="timecapsule",
        title="미래의 나에게",
        location_id=None,
        photo_path=None,
        caption="이때쯤이면 취업했으려나",
        memory_year=None,
        reveal_at=None,
        hidden=False,
        created_at=datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc),
    )
    defaults.update(overrides)
    return CommunityPost(**defaults)


def test_timecapsule_hides_content_before_reveal_at() -> None:
    future = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=30)
    post = _make_post(reveal_at=future)

    response = CommunityService._to_response(post, author_nickname="옛길이")

    assert response.revealed is False
    assert response.title is None
    assert response.caption is None
    assert response.photo_urls == []
    assert response.reveal_at == future


def test_timecapsule_shows_content_after_reveal_at() -> None:
    past = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1)
    post = _make_post(reveal_at=past)

    response = CommunityService._to_response(post, author_nickname="옛길이")

    assert response.revealed is True
    assert response.title == "미래의 나에게"
    assert response.caption == "이때쯤이면 취업했으려나"


def test_non_timecapsule_boards_are_always_revealed() -> None:
    post = _make_post(board="free", reveal_at=None)

    response = CommunityService._to_response(post, author_nickname="옛길이")

    assert response.revealed is True
    assert response.title == "미래의 나에게"


# -- 타임캡슐: 생성 검증 --------------------------------------------------------


@pytest.mark.asyncio
async def test_create_timecapsule_post_requires_future_reveal_at() -> None:
    service = CommunityService()
    with pytest.raises(Exception) as exc_info:  # noqa: PT011 - HTTPException from fastapi
        await service.create_post(
            db=None,  # 검증 단계에서 걸려서 db에 닿지 않는다.
            user=_FAKE_USER,
            region="경기 수원시 영통구",
            board="timecapsule",
            title="편지",
            caption="내용",
            reveal_at=None,
        )
    assert "422" in str(exc_info.value) or getattr(exc_info.value, "status_code", None) == 422


@pytest.mark.asyncio
async def test_create_timecapsule_post_rejects_past_date() -> None:
    service = CommunityService()
    past = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1)
    with pytest.raises(Exception) as exc_info:  # noqa: PT011
        await service.create_post(
            db=None,
            user=_FAKE_USER,
            region="경기 수원시 영통구",
            board="timecapsule",
            title="편지",
            caption="내용",
            reveal_at=past,
        )
    assert getattr(exc_info.value, "status_code", None) == 422


def test_create_post_route_accepts_timecapsule_board(monkeypatch) -> None:
    from app.models.community import CommunityPostResponse

    captured: dict = {}

    async def _fake_create_post(self: CommunityService, db, user, **kwargs):  # noqa: ANN001, ARG001
        captured.update(kwargs)
        return CommunityPostResponse(
            id=1, author_id=user.id, author_nickname=user.nickname,
            region=kwargs["region"], board=kwargs["board"], title=kwargs.get("title"),
            caption=kwargs.get("caption"), reveal_at=kwargs.get("reveal_at"), revealed=False,
            created_at="2026-09-13T00:00:00+00:00",
        )

    monkeypatch.setattr(CommunityService, "create_post", _fake_create_post)
    app.dependency_overrides[get_current_user] = lambda: _FAKE_USER
    try:
        response = client.post(
            "/api/community/posts",
            data={
                "region": "경기 수원시 영통구",
                "board": "timecapsule",
                "title": "미래의 나에게",
                "caption": "잘 지내고 있니",
                "reveal_at": "2030-01-01T00:00:00Z",
            },
        )
        assert response.status_code == 200
        assert captured["board"] == "timecapsule"
        assert captured["reveal_at"] is not None
        assert response.json()["revealed"] is False
    finally:
        app.dependency_overrides.pop(get_current_user, None)


# -- 장소별 추억 타임라인 -------------------------------------------------------


def test_timeline_route_rejects_unknown_board() -> None:
    response = client.get(
        "/api/community/posts/timeline", params={"region": "경기 수원시 영통구", "board": "not-real"}
    )
    assert response.status_code == 400


def test_timeline_route_delegates_to_service(monkeypatch) -> None:
    from app.models.community import CommunityPostResponse

    async def _fake_timeline(self: CommunityService, db, *, region, board="memory", viewer_id=None):  # noqa: ANN001, ARG001
        return [
            CommunityPostResponse(
                id=1, author_id=1, author_nickname="옛길이", region=region, board=board,
                memory_year=1998, created_at="2026-09-13T00:00:00+00:00",
            ),
            CommunityPostResponse(
                id=2, author_id=1, author_nickname="옛길이", region=region, board=board,
                memory_year=2005, created_at="2026-09-13T00:00:00+00:00",
            ),
        ]

    monkeypatch.setattr(CommunityService, "timeline", _fake_timeline)
    response = client.get(
        "/api/community/posts/timeline", params={"region": "경기 수원시 영통구", "board": "memory"}
    )
    assert response.status_code == 200
    body = response.json()
    assert [item["memory_year"] for item in body] == [1998, 2005]


# -- 모교 커뮤니티(동창찾기) ----------------------------------------------------


def test_search_schools_route(monkeypatch) -> None:
    from app.services.kakao_local import KakaoLocalService

    async def _fake_search_schools(self: KakaoLocalService, query: str, limit: int = 8):  # noqa: ARG001
        return [{"id": "1", "name": "옛길고등학교", "address": "경기 수원시", "latitude": 37.0, "longitude": 127.0}]

    monkeypatch.setattr(KakaoLocalService, "search_schools", _fake_search_schools)
    response = client.get("/api/community/schools", params={"query": "옛길고"})
    assert response.status_code == 200
    body = response.json()
    assert body == [{"id": "1", "name": "옛길고등학교", "address": "경기 수원시"}]


def test_active_authors_requires_auth() -> None:
    response = client.get("/api/community/active-authors", params={"region": "학교·옛길고등학교"})
    assert response.status_code == 401


def test_active_authors_route_delegates_to_service(monkeypatch) -> None:
    from app.models.community import NeighborResponse

    async def _fake_active_authors(self: CommunityService, db, user, *, region):  # noqa: ANN001, ARG001
        return [NeighborResponse(user_id=2, nickname="동창1", post_count=3)]

    monkeypatch.setattr(CommunityService, "active_authors", _fake_active_authors)
    app.dependency_overrides[get_current_user] = lambda: _FAKE_USER
    try:
        response = client.get("/api/community/active-authors", params={"region": "학교·옛길고등학교"})
        assert response.status_code == 200
        assert response.json() == [{"user_id": 2, "nickname": "동창1", "profile_image_url": None, "post_count": 3}]
    finally:
        app.dependency_overrides.pop(get_current_user, None)
