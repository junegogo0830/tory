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
from app.models.course import CourseResponse
from app.models.custom_course import CustomCourseCreateRequest, CustomCoursePlaceInput
from app.models.profile import ProfileInfoUpdateRequest
from app.services.custom_course import CustomCourseService
from app.services.profile import ProfileService
from app.services.recommendation import RecommendationService

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


def _fake_course(course_id: str) -> CourseResponse:
    return CourseResponse(
        id=course_id,
        title="벚꽃길 코스",
        description="설명",
        sentiment_score=0.8,
        stops=[],
        duration_label="2시간",
        category="산책",
    )


@pytest.mark.asyncio
async def test_save_generated_course_snapshots_and_is_idempotent(db, monkeypatch):
    async def _fake_get_course_by_id(self, course_id):
        return _fake_course(course_id)

    monkeypatch.setattr(RecommendationService, "get_course_by_id", _fake_get_course_by_id)

    service = ProfileService()
    user = User(kakao_id="save-gen", nickname="나")
    db.add(user)
    await db.commit()

    assert await service.is_course_saved(db, user, "generated", "llm-1") is False
    await service.save_course(db, user, "generated", "llm-1")
    await service.save_course(db, user, "generated", "llm-1")  # 중복 저장은 조용히 무시.
    assert await service.is_course_saved(db, user, "generated", "llm-1") is True

    saved = await service.list_saved_courses(db, user)
    assert len(saved) == 1
    assert saved[0].course_type == "generated"
    assert saved[0].title == "벚꽃길 코스"

    await service.unsave_course(db, user, "generated", "llm-1")
    assert await service.is_course_saved(db, user, "generated", "llm-1") is False


@pytest.mark.asyncio
async def test_save_generated_course_404_when_not_found(db, monkeypatch):
    async def _none(self, course_id):
        return None

    monkeypatch.setattr(RecommendationService, "get_course_by_id", _none)

    service = ProfileService()
    user = User(kakao_id="save-gen-404", nickname="나")
    db.add(user)
    await db.commit()

    with pytest.raises(HTTPException):
        await service.save_course(db, user, "generated", "missing")


@pytest.mark.asyncio
async def test_save_generated_course_with_explicit_snapshot_skips_refetch(db, monkeypatch):
    """식사 추가는 서버 캐시에 없는 화면 전용 변경이라, 저장 시점에 id로 다시
    조회하면 방금 추가한 식당이 사라진다 — course를 직접 넘기면 그 스냅샷을
    그대로 믿어야 한다."""

    async def _stale_get_course_by_id(self, course_id):
        return _fake_course(course_id)  # 식사가 없는 "원본" — 호출되면 안 된다.

    monkeypatch.setattr(RecommendationService, "get_course_by_id", _stale_get_course_by_id)

    service = ProfileService()
    user = User(kakao_id="save-gen-snapshot", nickname="나")
    db.add(user)
    await db.commit()

    with_meal = _fake_course("llm-2").model_copy(update={"title": "벚꽃길 코스 (점심식당 포함)"})
    await service.save_course(db, user, "generated", "llm-2", course=with_meal)

    saved = await service.list_saved_courses(db, user)
    assert len(saved) == 1
    assert saved[0].title == "벚꽃길 코스 (점심식당 포함)"


@pytest.mark.asyncio
async def test_save_custom_course_resolves_live_and_skips_deleted(db):
    course_service = CustomCourseService()
    profile_service = ProfileService()
    author = User(kakao_id="save-custom", nickname="작성자")
    db.add(author)
    await db.commit()

    course = await course_service.create(
        db,
        author,
        CustomCourseCreateRequest(
            title="나만의 코스",
            category="산책",
            places=[CustomCoursePlaceInput(source="tour", place_id="tour-1", name="한강공원")],
        ),
    )

    await profile_service.save_course(db, author, "custom", str(course.id))
    saved = await profile_service.list_saved_courses(db, author)
    assert len(saved) == 1
    assert saved[0].title == "나만의 코스"

    await course_service.remove(db, course.id, author)
    # 삭제된 커스텀 코스는 목록에서 조용히 빠진다.
    assert await profile_service.list_saved_courses(db, author) == []


@pytest.mark.asyncio
async def test_update_info_rejects_duplicate_phone_number(db):
    service = ProfileService()
    taken = User(kakao_id="phone-a", nickname="A", phone_number="01011112222")
    me = User(kakao_id="phone-b", nickname="B")
    db.add_all([taken, me])
    await db.commit()

    with pytest.raises(HTTPException):
        await service.update_info(db, me, ProfileInfoUpdateRequest(phone_number="01011112222"))

    updated = await service.update_info(
        db, me, ProfileInfoUpdateRequest(gender="여성", full_name="김철수", phone_number="01099998888")
    )
    assert updated.gender == "여성"
    assert updated.full_name == "김철수"
    assert updated.phone_number == "01099998888"
