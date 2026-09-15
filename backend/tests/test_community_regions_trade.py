import os
import uuid

import pytest
import pytest_asyncio
from fastapi import HTTPException
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings
from app.db.base import Base
from app.db.models import RegionMembership, User
from app.services.community import CommunityService

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


@pytest.mark.asyncio
async def test_set_home_region_records_membership_once(db):
    service = CommunityService()
    user = User(kakao_id="region-user", nickname="나")
    db.add(user)
    await db.commit()

    await service.set_home_region(db, user, "서울 종로구")
    await service.set_home_region(db, user, "서울 종로구")  # 같은 지역 재설정 — 중복 안 됨.
    await service.set_home_region(db, user, "경기 수원시")

    rows = (await db.execute(select(RegionMembership).where(RegionMembership.user_id == user.id))).scalars().all()
    assert {r.region for r in rows} == {"서울 종로구", "경기 수원시"}
    assert user.home_region == "경기 수원시"

    regions = await service.list_my_regions(db, user)
    assert regions == ["경기 수원시", "서울 종로구"]  # 최근 가입 순


@pytest.mark.asyncio
async def test_region_stats_counts_members_and_posts(db):
    service = CommunityService()
    a = User(kakao_id="stats-a", nickname="A")
    b = User(kakao_id="stats-b", nickname="B")
    db.add_all([a, b])
    await db.commit()

    await service.set_home_region(db, a, "서울 마포구")
    await service.set_home_region(db, b, "서울 마포구")
    await service.create_post(db, a, region="서울 마포구", board="free", title="글", caption="내용")

    stats = await service.region_stats(db, "서울 마포구")
    assert stats.member_count == 2
    assert stats.post_count == 1

    empty_stats = await service.region_stats(db, "아무도 없는 동네")
    assert empty_stats.member_count == 0 and empty_stats.post_count == 0


@pytest.mark.asyncio
async def test_resident_board_post_defaults_and_validates_trade_fields(db):
    service = CommunityService()
    user = User(kakao_id="trade-user", nickname="나")
    db.add(user)
    await db.commit()

    # 거래상태를 안 주면 "판매중"이 기본.
    post = await service.create_post(db, user, region="서울 종로구", board="resident", title="자전거 팔아요", price=30000)
    assert post.trade_status == "판매중"
    assert post.price == 30000

    # 가격 없이 올리면 "나눔"으로 취급할 수 있게 None 유지.
    free_post = await service.create_post(db, user, region="서울 종로구", board="resident", title="책 나눔")
    assert free_post.price is None
    assert free_post.trade_status == "판매중"

    # 다른 게시판엔 가격/거래상태가 절대 안 붙는다.
    free_board_post = await service.create_post(
        db, user, region="서울 종로구", board="free", title="일반 글", price=1000, trade_status="예약중"
    )
    assert free_board_post.price is None
    assert free_board_post.trade_status is None

    with pytest.raises(HTTPException):
        await service.create_post(db, user, region="서울 종로구", board="resident", title="음수 가격", price=-1)


@pytest.mark.asyncio
async def test_resident_board_free_category_post_has_no_trade_fields(db):
    """주민 게시판에서 "자유글" 카테고리를 고르면(is_trade=False) 가격/거래상태가 붙지 않는다."""
    service = CommunityService()
    user = User(kakao_id="trade-user-2", nickname="나")
    db.add(user)
    await db.commit()

    post = await service.create_post(
        db, user, region="서울 종로구", board="resident", title="동네 이야기", price=5000, is_trade=False
    )
    assert post.price is None
    assert post.trade_status is None


@pytest.mark.asyncio
async def test_update_trade_status_requires_ownership_and_resident_board(db):
    service = CommunityService()
    owner = User(kakao_id="trade-owner", nickname="주인")
    other = User(kakao_id="trade-other", nickname="타인")
    db.add_all([owner, other])
    await db.commit()

    post = await service.create_post(db, owner, region="서울 종로구", board="resident", title="중고 의자", price=5000)

    with pytest.raises(HTTPException) as exc:
        await service.update_trade_status(db, post.id, other, "예약중")
    assert exc.value.status_code == 403

    updated = await service.update_trade_status(db, post.id, owner, "예약중")
    assert updated.trade_status == "예약중"

    free_post = await service.create_post(db, owner, region="서울 종로구", board="free", title="일반 글", caption="내용")
    with pytest.raises(HTTPException) as exc:
        await service.update_trade_status(db, free_post.id, owner, "예약중")
    assert exc.value.status_code == 422
