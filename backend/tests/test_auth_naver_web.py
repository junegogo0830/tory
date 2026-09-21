import os
import uuid

import pytest
import pytest_asyncio
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings
from app.core.security import decode_token
from app.db.base import Base
from app.db.models import User
from app.services.auth import AuthService
from app.services.naver_auth import NaverAuthService, NaverProfile

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
async def test_login_with_naver_code_exchanges_then_upserts_user(db, monkeypatch):
    """웹 로그인 전체 경로 — authorization code를 네이버 액세스 토큰으로 교환한 뒤
    (실제 네이버 서버 호출 없이 monkeypatch), kakao와 같은 upsert 로직으로
    이어지는지 확인한다."""

    async def _exchange(self, code: str, state: str, redirect_uri: str) -> str:
        assert code == "auth-code-from-naver"
        assert state == "csrf-state"
        assert redirect_uri == "http://localhost:5000/"
        return "naver-access-token-from-code"

    async def _fetch_profile(self, naver_access_token: str) -> NaverProfile:
        assert naver_access_token == "naver-access-token-from-code"
        return NaverProfile(naver_id="web-login-user", nickname="웹로그인유저")

    monkeypatch.setattr(NaverAuthService, "exchange_code_for_token", _exchange)
    monkeypatch.setattr(NaverAuthService, "fetch_profile", _fetch_profile)

    service = AuthService()
    access_token, refresh_token = await service.login_with_naver_code(
        db, "auth-code-from-naver", "csrf-state", "http://localhost:5000/"
    )

    user = (await db.execute(select(User).where(User.naver_id == "web-login-user"))).scalar_one()
    assert user.nickname == "웹로그인유저"
    assert decode_token(access_token, expected_type="access") == user.id
    assert decode_token(refresh_token, expected_type="refresh") == user.id

    # 같은 네이버 계정으로 다시 로그인하면(재교환) 새 유저를 만들지 않고 닉네임만 갱신한다.
    async def _fetch_profile_renamed(self, naver_access_token: str) -> NaverProfile:
        return NaverProfile(naver_id="web-login-user", nickname="닉네임변경")

    monkeypatch.setattr(NaverAuthService, "fetch_profile", _fetch_profile_renamed)
    await service.login_with_naver_code(db, "auth-code-from-naver", "csrf-state", "http://localhost:5000/")
    rows = (await db.execute(select(User).where(User.naver_id == "web-login-user"))).scalars().all()
    assert len(rows) == 1
    assert rows[0].nickname == "닉네임변경"
