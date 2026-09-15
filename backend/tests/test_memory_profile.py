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
from app.models.custom_course import CustomCourseCreateRequest, CustomCoursePlaceInput
from app.models.memory import MemoryAttributeCreateRequest, MemorySearchFilter
from app.services.custom_course import CustomCourseService
from app.services.memory_profile import MemoryProfileService, _canonical_place_id, _years_overlap

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


def test_years_overlap_treats_none_as_open_ended():
    assert _years_overlap(2008, 2010, 2009, 2012) is True
    assert _years_overlap(2008, 2010, 2011, 2012) is False
    assert _years_overlap(None, None, 2020, 2021) is True
    assert _years_overlap(2008, None, 2020, None) is True


def test_canonical_place_id_normalizes_kakao_but_not_tour():
    assert _canonical_place_id("kakao", "12345") == "kakao-12345"
    assert _canonical_place_id("kakao", "kakao-12345") == "kakao-12345"
    assert _canonical_place_id("tour", "tour-999") == "tour-999"


@pytest.mark.asyncio
async def test_add_list_delete_attribute_requires_ownership(db):
    service = MemoryProfileService()
    owner = User(kakao_id="owner", nickname="나")
    other = User(kakao_id="other", nickname="남")
    db.add_all([owner, other])
    await db.commit()

    added = await service.add_attribute(
        db, owner, MemoryAttributeCreateRequest(type="school", label="옛길고등학교", start_year=2008, end_year=2010)
    )
    attrs = await service.list_attributes(db, owner.id)
    assert [a.id for a in attrs] == [added.id]

    with pytest.raises(HTTPException):
        await service.delete_attribute(db, other, added.id)

    await service.delete_attribute(db, owner, added.id)
    assert await service.list_attributes(db, owner.id) == []


@pytest.mark.asyncio
async def test_search_matches_ranks_school_over_region_only(db):
    service = MemoryProfileService()
    me = User(kakao_id="me", nickname="나")
    schoolmate = User(kakao_id="schoolmate", nickname="같은학교")
    neighbor = User(kakao_id="neighbor", nickname="같은동네")
    stranger = User(kakao_id="stranger", nickname="무관")
    db.add_all([me, schoolmate, neighbor, stranger])
    await db.commit()

    await service.add_attribute(
        db, schoolmate, MemoryAttributeCreateRequest(type="school", label="옛길고등학교", start_year=2008, end_year=2010)
    )
    await service.add_attribute(
        db, neighbor, MemoryAttributeCreateRequest(type="region", label="고잔동", start_year=2008, end_year=2010)
    )
    await service.add_attribute(
        db, stranger, MemoryAttributeCreateRequest(type="school", label="다른고등학교", start_year=2015, end_year=2018)
    )

    filters = [
        MemorySearchFilter(type="school", label="옛길고등학교", start_year=2009, end_year=2009),
        MemorySearchFilter(type="region", label="고잔동", start_year=2009, end_year=2009),
    ]
    results = await service.search_matches(db, me, filters)

    result_ids = [r.user_id for r in results]
    assert stranger.id not in result_ids
    assert result_ids[0] == schoolmate.id  # 학교 매칭(40점)이 동네 매칭(20점)보다 위.
    assert results[0].score > results[1].score
    assert "옛길고등학교" in results[0].reasons[0]


@pytest.mark.asyncio
async def test_overlap_for_course_matches_place_and_creator_school(db):
    course_service = CustomCourseService()
    memory_service = MemoryProfileService()
    creator = User(kakao_id="creator", nickname="작성자")
    place_matcher = User(kakao_id="place-matcher", nickname="같은장소")
    school_matcher = User(kakao_id="school-matcher", nickname="같은학교")
    unrelated = User(kakao_id="unrelated", nickname="무관")
    db.add_all([creator, place_matcher, school_matcher, unrelated])
    await db.commit()

    await memory_service.add_attribute(
        db, creator, MemoryAttributeCreateRequest(type="school", label="중앙고등학교", start_year=2008, end_year=2010)
    )
    await memory_service.add_attribute(
        db, school_matcher, MemoryAttributeCreateRequest(type="school", label="중앙고등학교", start_year=2009, end_year=2011)
    )
    await memory_service.add_attribute(
        db,
        place_matcher,
        MemoryAttributeCreateRequest(type="place", label="중앙역", place_id="kakao-500"),
    )
    await memory_service.add_attribute(
        db, unrelated, MemoryAttributeCreateRequest(type="school", label="상관없는고", start_year=1990, end_year=1993)
    )

    course = await course_service.create(
        db,
        creator,
        CustomCourseCreateRequest(
            title="2008년 중앙동 하굣길",
            category="산책",
            places=[
                CustomCoursePlaceInput(source="kakao", place_id="500", name="중앙역", address="", latitude=37.0, longitude=127.0),
            ],
        ),
    )
    course_row = await course_service.require_course(db, course.id)

    matches = await memory_service.overlap_for_course(db, course_row)
    result_ids = {m.user_id for m in matches}

    assert result_ids == {place_matcher.id, school_matcher.id}
    assert creator.id not in result_ids
    assert unrelated.id not in result_ids
    place_match = next(m for m in matches if m.user_id == place_matcher.id)
    assert "중앙역" in place_match.reasons[0]
