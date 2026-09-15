import os
import uuid

import pytest
import pytest_asyncio
from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings
from app.db.base import Base
from app.db.models import User
from app.models.custom_course import CustomCourseCreateRequest, CustomCoursePlaceInput, CustomCourseUpdateRequest
from app.services.custom_course import CustomCourseService

pytestmark = pytest.mark.skipif(os.environ.get("RUN_DB_TESTS") != "1", reason="Requires isolated PostgreSQL schema")


@pytest_asyncio.fixture
async def db():
    schema = "test_" + uuid.uuid4().hex
    admin = create_async_engine(settings.database_url)
    async with admin.begin() as conn:
        await conn.execute(text("CREATE SCHEMA " + schema))
    engine = create_async_engine(settings.database_url, connect_args={"server_settings": {"search_path": schema}})
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with async_sessionmaker(engine, expire_on_commit=False)() as session:
            yield session
    finally:
        await engine.dispose()
        async with admin.begin() as conn:
            await conn.execute(text("DROP SCHEMA " + schema + " CASCADE"))
        await admin.dispose()


def _create_request(**overrides) -> CustomCourseCreateRequest:
    defaults = dict(
        title="나만의 벚꽃길 코스",
        category="산책",
        description="주말 오후 산책하기 좋은 코스예요",
        places=[
            CustomCoursePlaceInput(
                source="tour", place_id="tour-1", name="한강공원", address="서울 영등포구", latitude=37.5, longitude=126.9
            ),
            CustomCoursePlaceInput(
                source="kakao", place_id="kakao-1", name="근처 카페", address="서울 영등포구 123", latitude=37.51, longitude=126.91
            ),
        ],
    )
    defaults.update(overrides)
    return CustomCourseCreateRequest(**defaults)


@pytest.mark.asyncio
async def test_create_and_list_custom_course(db):
    service = CustomCourseService()
    author = User(kakao_id="course-author", nickname="작성자")
    db.add(author)
    await db.commit()

    created = await service.create(db, author, _create_request())
    assert created.title == "나만의 벚꽃길 코스"
    assert len(created.places) == 2
    assert created.is_mine
    assert created.my_vote == 0

    summaries = await service.list_courses(db)
    assert len(summaries) == 1
    assert summaries[0].place_count == 2
    assert summaries[0].thumbnail_url is None

    # 카테고리로 필터링.
    assert len(await service.list_courses(db, category="산책")) == 1
    assert len(await service.list_courses(db, category="역사")) == 0


@pytest.mark.asyncio
async def test_list_courses_filters_by_author(db):
    service = CustomCourseService()
    me = User(kakao_id="mine-author", nickname="나")
    other = User(kakao_id="other-author", nickname="다른사람")
    db.add_all([me, other])
    await db.commit()

    my_course = await service.create(db, me, _create_request(title="내 코스"))
    await service.create(db, other, _create_request(title="남의 코스"))

    mine = await service.list_courses(db, author_id=me.id)
    assert [c.title for c in mine] == ["내 코스"]
    assert mine[0].id == my_course.id

    assert len(await service.list_courses(db)) == 2


@pytest.mark.asyncio
async def test_vote_toggle_and_score(db):
    service = CustomCourseService()
    author = User(kakao_id="vote-author", nickname="작성자")
    voter = User(kakao_id="vote-voter", nickname="투표자")
    db.add_all([author, voter])
    await db.commit()
    course = await service.create(db, author, _create_request())

    upvoted = await service.vote(db, course.id, voter, 1)
    assert upvoted.like_count == 1 and upvoted.dislike_count == 0
    assert upvoted.my_vote == 1

    # 같은 사람이 반대로 바꾸면 upsert로 값만 바뀐다(중복 행이 생기지 않는다).
    downvoted = await service.vote(db, course.id, voter, -1)
    assert downvoted.like_count == 0 and downvoted.dislike_count == 1
    assert downvoted.my_vote == -1

    # 0으로 보내면 투표가 취소된다.
    cancelled = await service.vote(db, course.id, voter, 0)
    assert cancelled.like_count == 0 and cancelled.dislike_count == 0
    assert cancelled.my_vote == 0

    summaries = await service.list_courses(db, sort="popular")
    assert summaries[0].score == 0


@pytest.mark.asyncio
async def test_comments_and_ownership(db):
    service = CustomCourseService()
    author = User(kakao_id="comment-author", nickname="작성자")
    commenter = User(kakao_id="comment-other", nickname="댓글러")
    db.add_all([author, commenter])
    await db.commit()
    course = await service.create(db, author, _create_request())

    comment = await service.add_comment(db, course.id, commenter, "좋은 코스네요")
    assert comment.author_nickname == "댓글러"
    assert comment.is_mine

    comments = await service.comments(db, course.id, author)
    assert len(comments) == 1
    assert comments[0].is_mine is False  # author가 조회하지만 댓글 작성자는 commenter

    detail = await service.detail(db, course.id)
    assert detail.comment_count == 1

    with pytest.raises(HTTPException) as exc:
        await service.remove_comment(db, course.id, comment.id, author)
    assert exc.value.status_code == 403

    await service.remove_comment(db, course.id, comment.id, commenter)
    assert await service.comments(db, course.id) == []


@pytest.mark.asyncio
async def test_delete_requires_ownership_and_cascades_votes_comments(db):
    service = CustomCourseService()
    author = User(kakao_id="delete-author", nickname="작성자")
    other = User(kakao_id="delete-other", nickname="타인")
    db.add_all([author, other])
    await db.commit()
    course = await service.create(db, author, _create_request())
    await service.vote(db, course.id, other, 1)
    await service.add_comment(db, course.id, other, "댓글")

    with pytest.raises(HTTPException) as exc:
        await service.remove(db, course.id, other)
    assert exc.value.status_code == 403

    await service.remove(db, course.id, author)
    with pytest.raises(HTTPException):
        await service.detail(db, course.id)
    assert (await db.execute(text("SELECT count(*) FROM custom_course_votes"))).scalar() == 0
    assert (await db.execute(text("SELECT count(*) FROM custom_course_comments"))).scalar() == 0


@pytest.mark.asyncio
async def test_invalid_category_rejected():
    with pytest.raises(ValueError):
        _create_request(category="없는카테고리")


@pytest.mark.asyncio
async def test_place_notes_round_trip(db):
    service = CustomCourseService()
    author = User(kakao_id="note-author", nickname="작성자")
    db.add(author)
    await db.commit()

    request = _create_request(
        places=[
            CustomCoursePlaceInput(
                source="tour",
                place_id="tour-1",
                name="한강공원",
                address="서울 영등포구",
                latitude=37.5,
                longitude=126.9,
                note="노을이 예쁜 곳이에요",
            ),
            CustomCoursePlaceInput(source="kakao", place_id="kakao-1", name="근처 카페", address="서울 영등포구 123"),
        ]
    )
    created = await service.create(db, author, request)
    assert created.places[0].note == "노을이 예쁜 곳이에요"
    assert created.places[1].note is None

    detail = await service.detail(db, created.id)
    assert detail.places[0].note == "노을이 예쁜 곳이에요"


@pytest.mark.asyncio
async def test_private_course_hidden_from_others_and_public_list(db):
    service = CustomCourseService()
    author = User(kakao_id="private-author", nickname="작성자")
    other = User(kakao_id="private-other", nickname="다른사람")
    db.add_all([author, other])
    await db.commit()

    private_course = await service.create(db, author, _create_request(title="비공개 코스", is_public=False))
    await service.create(db, author, _create_request(title="공개 코스"))

    # 일반 목록에는 공개 코스만 보인다.
    public_titles = [c.title for c in await service.list_courses(db)]
    assert public_titles == ["공개 코스"]

    # "내 코스" 목록(author_id 지정)에는 비공개도 포함된다.
    mine_titles = {c.title for c in await service.list_courses(db, author_id=author.id)}
    assert mine_titles == {"비공개 코스", "공개 코스"}

    # 작성자 본인은 상세 조회 가능.
    detail = await service.detail(db, private_course.id, author)
    assert detail.is_public is False

    # 다른 사람/비로그인은 404.
    with pytest.raises(HTTPException) as exc:
        await service.detail(db, private_course.id, other)
    assert exc.value.status_code == 404
    with pytest.raises(HTTPException):
        await service.detail(db, private_course.id)


@pytest.mark.asyncio
async def test_list_public_by_author_never_leaks_private_courses(db):
    """추억 프로필의 "만든 코스" 섹션이 쓰는 엔드포인트 — list_courses의 author_id
    필터("내 코스", 비공개 포함)와 절대 혼동하면 안 된다."""
    service = CustomCourseService()
    author = User(kakao_id="by-author", nickname="작성자")
    db.add(author)
    await db.commit()

    await service.create(db, author, _create_request(title="비공개 코스", is_public=False))
    await service.create(db, author, _create_request(title="공개 코스"))

    titles = [c.title for c in await service.list_public_by_author(db, author.id)]
    assert titles == ["공개 코스"]


@pytest.mark.asyncio
async def test_update_requires_ownership_and_replaces_fields(db):
    service = CustomCourseService()
    author = User(kakao_id="update-author", nickname="작성자")
    other = User(kakao_id="update-other", nickname="타인")
    db.add_all([author, other])
    await db.commit()
    course = await service.create(db, author, _create_request(title="원래 제목"))

    with pytest.raises(HTTPException) as exc:
        await service.update(db, course.id, other, CustomCourseUpdateRequest(**_create_request(title="탈취 시도").model_dump()))
    assert exc.value.status_code == 403

    update_body = CustomCourseUpdateRequest(
        title="수정된 제목",
        category="역사",
        description="수정된 소개",
        places=[
            CustomCoursePlaceInput(source="tour", place_id="tour-2", name="새 장소", address="서울", latitude=37.6, longitude=127.0)
        ],
        is_public=False,
    )
    updated = await service.update(db, course.id, author, update_body)
    assert updated.title == "수정된 제목"
    assert updated.category == "역사"
    assert updated.description == "수정된 소개"
    assert [p.name for p in updated.places] == ["새 장소"]
    assert updated.is_public is False


@pytest.mark.asyncio
async def test_render_map_uses_places_with_coordinates(db, monkeypatch):
    from app.services import custom_course as custom_course_module

    monkeypatch.setattr(custom_course_module.settings, "kakao_map_js_key", "test-js-key")

    service = CustomCourseService()
    author = User(kakao_id="map-author", nickname="작성자")
    db.add(author)
    await db.commit()
    course = await service.create(
        db,
        author,
        _create_request(
            places=[
                CustomCoursePlaceInput(
                    source="tour", place_id="tour-1", name="한강공원", address="서울 영등포구", latitude=37.5, longitude=126.9
                ),
                # 좌표 없는 장소는 마커에서 빠져야 한다.
                CustomCoursePlaceInput(source="kakao", place_id="kakao-1", name="근처 카페", address="서울 영등포구 123"),
            ]
        ),
    )

    html = await service.render_map(db, course.id)
    assert "한강공원" in html
    assert "kakao.maps.Map" in html
    assert "근처 카페" not in html


@pytest.mark.asyncio
async def test_render_map_without_js_key_shows_message(db, monkeypatch):
    from app.services import custom_course as custom_course_module

    monkeypatch.setattr(custom_course_module.settings, "kakao_map_js_key", "")

    service = CustomCourseService()
    author = User(kakao_id="map-nokey-author", nickname="작성자")
    db.add(author)
    await db.commit()
    course = await service.create(db, author, _create_request())

    html = await service.render_map(db, course.id)
    assert "카카오맵 키가 설정되지 않았어요" in html
