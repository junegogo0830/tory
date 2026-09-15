import os
import uuid
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy import text
from app.core.config import settings
from app.db.base import Base
from app.db.models import SavedLocation, User
from app.models.course import CourseResponse, CourseStop
from app.models.location import LocationResponse
from app.services.community import CommunityService
from app.services.discovery import DiscoveryService
from app.services.profile import ProfileService
from app.services.tourapi import TourApiService

pytestmark = pytest.mark.skipif(os.environ.get('RUN_DB_TESTS') != '1', reason='Requires isolated PostgreSQL schema')


@pytest_asyncio.fixture
async def db():
    schema = 'test_' + uuid.uuid4().hex
    admin = create_async_engine(settings.database_url)
    async with admin.begin() as conn:
        await conn.execute(text('CREATE SCHEMA ' + schema))
    engine = create_async_engine(settings.database_url, connect_args={'server_settings': {'search_path': schema}})
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with async_sessionmaker(engine, expire_on_commit=False)() as session:
            yield session
    finally:
        await engine.dispose()
        async with admin.begin() as conn:
            await conn.execute(text('DROP SCHEMA ' + schema + ' CASCADE'))
        await admin.dispose()


@pytest.mark.asyncio
async def test_memories_returns_only_own_posts_with_photos(db):
    service = CommunityService()
    profile = ProfileService()
    me = User(kakao_id='memories-me', nickname='나')
    other = User(kakao_id='memories-other', nickname='남')
    db.add_all([me, other])
    await db.commit()

    await service.create_post(db, me, region='서울 종로구', board='free', title='글만', caption='사진 없음')
    await service.create_post(
        db, me, region='서울 종로구', board='memory', title='추억', caption='사진 있음',
        files=[_FakeUploadFile(b'\xff\xd8\xff' + b'0' * 20, 'image/jpeg')], memory_year=2005,
    )
    await service.create_post(
        db, other, region='서울 종로구', board='memory', title='남의 추억',
        files=[_FakeUploadFile(b'\xff\xd8\xff' + b'0' * 20, 'image/jpeg')],
    )

    memories = await profile.get_memories(db, me)
    assert len(memories) == 1
    assert memories[0].title == '추억'
    assert memories[0].memory_year == 2005
    assert memories[0].photo_url.startswith('/uploads/community/')


@pytest.mark.asyncio
async def test_my_courses_roundtrip(db):
    profile = ProfileService()
    me = User(kakao_id='courses-me', nickname='나')
    db.add(me)
    await db.commit()

    course = CourseResponse(
        id='plan-abc123', title='가을 산책', description='설명', sentiment_score=0.8,
        stops=[CourseStop(name='공원')], duration_label='약 2시간', category='산책',
    )
    await profile.save_generated_course(db, me, course)

    saved = await profile.get_my_courses(db, me)
    assert len(saved) == 1
    assert saved[0].id == 'plan-abc123'
    assert saved[0].title == '가을 산책'


@pytest.mark.asyncio
async def test_complete_onboarding_sets_age_group_and_flag(db):
    profile = ProfileService()
    me = User(kakao_id='onboarding-me', nickname='나')
    db.add(me)
    await db.commit()

    before = await profile.get_profile(db, me)
    assert before.onboarding_completed is False
    assert before.age_group is None

    await profile.complete_onboarding(db, me, '30대')
    after = await profile.get_profile(db, me)
    assert after.onboarding_completed is True
    assert after.age_group == '30대'

    # 건너뛰기(age_group=None)로 다시 불러도 이미 있던 연령대는 안 지워진다.
    await profile.complete_onboarding(db, me, None)
    still = await profile.get_profile(db, me)
    assert still.age_group == '30대'
    assert still.onboarding_completed is True


@pytest.mark.asyncio
async def test_has_password_reflects_account_type(db):
    profile = ProfileService()
    kakao_user = User(kakao_id='haspw-kakao', nickname='카카오')
    password_user = User(username='haspwuser', password_hash='hashed', nickname='haspwuser')
    db.add_all([kakao_user, password_user])
    await db.commit()

    assert (await profile.get_profile(db, kakao_user)).has_password is False
    assert (await profile.get_profile(db, password_user)).has_password is True


@pytest.mark.asyncio
async def test_update_nickname_and_photo(db):
    profile = ProfileService()
    me = User(kakao_id='edit-me', nickname='옛이름')
    db.add(me)
    await db.commit()

    updated = await profile.update_nickname(db, me, '새이름')
    assert updated.nickname == '새이름'

    updated = await profile.update_photo(db, me, _FakeUploadFile(b'\xff\xd8\xff' + b'0' * 20, 'image/jpeg'))
    assert updated.profile_image_url is not None
    assert updated.profile_image_url.startswith('/uploads/profile/')


@pytest.mark.asyncio
async def test_delete_account_cascades_to_related_data(db):
    community = CommunityService()
    profile = ProfileService()
    me = User(kakao_id='delete-me', nickname='탈퇴자')
    db.add(me)
    await db.commit()
    post = await community.create_post(db, me, region='서울 종로구', board='free', title='글', caption='내용')
    await db.execute(SavedLocation.__table__.insert().values(user_id=me.id, location_id='suncheon-jeonpo'))
    await db.commit()

    user_id = me.id
    await profile.delete_account(db, me)

    assert await db.get(User, user_id) is None
    from app.db.models import CommunityPost
    assert await db.get(CommunityPost, post.id) is None


@pytest.mark.asyncio
async def test_popular_locations_ranks_by_save_count(db, monkeypatch):
    async def _fake_get_location(self, location_id):  # noqa: ARG001
        return LocationResponse(
            id=location_id, name=location_id, region='어딘가', description='d',
            past_year=2026, current_year=2026, source='mock',
        )

    monkeypatch.setattr(TourApiService, 'get_location_by_id', _fake_get_location)

    users = [User(kakao_id=f'popular-{i}', nickname=f'유저{i}') for i in range(3)]
    db.add_all(users)
    await db.commit()
    # "spot-a"는 2명, "spot-b"는 1명이 저장 — 인기순 1등은 spot-a여야 한다.
    db.add_all([
        SavedLocation(user_id=users[0].id, location_id='spot-a'),
        SavedLocation(user_id=users[1].id, location_id='spot-a'),
        SavedLocation(user_id=users[2].id, location_id='spot-b'),
    ])
    await db.commit()

    service = DiscoveryService()
    popular = await service.get_popular_locations(db, limit=10)
    assert [p.id for p in popular] == ['spot-a', 'spot-b']
    assert popular[0].saved_by_count == 2
    assert popular[1].saved_by_count == 1


class _FakeUploadFile:
    def __init__(self, content: bytes, content_type: str) -> None:
        self.content_type = content_type
        self.filename = "photo.jpg"
        self._content = content

    async def read(self, _n: int) -> bytes:
        return self._content
