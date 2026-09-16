import datetime
import os
import uuid

import pytest
import pytest_asyncio
from fastapi import HTTPException
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings
from app.core.security import TokenError, create_phone_verification_token, decode_phone_verification_token, decode_token
from app.db.base import Base
from app.db.models import PhoneVerification, User
from app.models.auth import SignupRequest
from app.services.auth import AuthService
from app.services.phone_verification import PhoneVerificationService

pytestmark = pytest.mark.skipif(os.environ.get("RUN_DB_TESTS") != "1", reason="Requires isolated PostgreSQL schema")

_PHONE = "010-1234-5678"
_PHONE_NORMALIZED = "01012345678"


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


class _FakeSmsService:
    """실제 NCP SENS 호출 없이 마지막으로 "보낸" 인증번호를 붙잡아둔다."""

    def __init__(self) -> None:
        self.sent: list[tuple[str, str]] = []

    async def send_sms(self, to: str, content: str) -> None:
        self.sent.append((to, content))

    @property
    def last_code(self) -> str:
        # "[옛길] 인증번호 [123456]를 5분 이내에..." 형식에서 6자리만 뽑는다.
        content = self.sent[-1][1]
        return content.split("[")[2].split("]")[0]


@pytest.mark.asyncio
async def test_send_and_verify_phone_code_success(db):
    sms = _FakeSmsService()
    service = PhoneVerificationService(sms_service=sms)

    await service.send_code(db, _PHONE)
    assert sms.sent[0][0] == _PHONE_NORMALIZED
    code = sms.last_code

    token = await service.verify_code(db, _PHONE, code)
    assert decode_phone_verification_token(token) == _PHONE_NORMALIZED


@pytest.mark.asyncio
async def test_verify_code_wrong_code_locks_after_max_attempts(db):
    sms = _FakeSmsService()
    service = PhoneVerificationService(sms_service=sms)
    await service.send_code(db, _PHONE)

    for _ in range(5):
        with pytest.raises(HTTPException) as exc:
            await service.verify_code(db, _PHONE, "000000")
        assert exc.value.status_code == 400

    # 5번 다 틀렸으니 이제 맞는 코드를 넣어도 429(다시 요청해야 함).
    with pytest.raises(HTTPException) as exc:
        await service.verify_code(db, _PHONE, sms.last_code)
    assert exc.value.status_code == 429


@pytest.mark.asyncio
async def test_verify_code_expired_rejected(db):
    sms = _FakeSmsService()
    service = PhoneVerificationService(sms_service=sms)
    await service.send_code(db, _PHONE)
    code = sms.last_code

    record = (await db.execute(select(PhoneVerification))).scalar_one()
    record.expires_at = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=1)
    await db.commit()

    with pytest.raises(HTTPException) as exc:
        await service.verify_code(db, _PHONE, code)
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_send_code_rate_limited_within_cooldown(db):
    sms = _FakeSmsService()
    service = PhoneVerificationService(sms_service=sms)
    await service.send_code(db, _PHONE)

    with pytest.raises(HTTPException) as exc:
        await service.send_code(db, _PHONE)
    assert exc.value.status_code == 429


@pytest.mark.asyncio
async def test_rejects_non_korean_mobile_number(db):
    service = PhoneVerificationService(sms_service=_FakeSmsService())
    with pytest.raises(HTTPException) as exc:
        await service.send_code(db, "02-1234-5678")
    assert exc.value.status_code == 422


def _signup_request(**overrides) -> SignupRequest:
    defaults = dict(
        username="newuser01",
        password="password123",
        agree_terms=True,
        agree_privacy=True,
        agree_marketing=False,
        phone_verification_token=create_phone_verification_token(_PHONE_NORMALIZED),
    )
    defaults.update(overrides)
    return SignupRequest(**defaults)


@pytest.mark.asyncio
async def test_signup_requires_terms_and_privacy_agreement(db):
    auth = AuthService()
    with pytest.raises(ValueError):
        await auth.signup(db, _signup_request(agree_terms=False))
    with pytest.raises(ValueError):
        await auth.signup(db, _signup_request(agree_privacy=False))


@pytest.mark.asyncio
async def test_signup_success_then_login(db):
    auth = AuthService()
    access_token, refresh_token = await auth.signup(db, _signup_request(username="tester01"))

    user = (await db.execute(select(User).where(User.username == "tester01"))).scalar_one()
    assert user.phone_number == _PHONE_NORMALIZED
    assert user.nickname == "tester01"  # 기본 닉네임은 아이디
    assert user.terms_agreed_at is not None and user.privacy_agreed_at is not None
    assert user.marketing_agreed is False
    assert decode_token(access_token, expected_type="access") == user.id
    assert decode_token(refresh_token, expected_type="refresh") == user.id

    # 이제 로그인도 된다.
    login_access, _ = await auth.login(db, "tester01", "password123")
    assert decode_token(login_access, expected_type="access") == user.id

    with pytest.raises(ValueError):
        await auth.login(db, "tester01", "wrong-password")
    with pytest.raises(ValueError):
        await auth.login(db, "no-such-user", "password123")


@pytest.mark.asyncio
async def test_change_password_requires_current_password(db):
    auth = AuthService()
    await auth.signup(db, _signup_request(username="pwuser"))
    user = (await db.execute(select(User).where(User.username == "pwuser"))).scalar_one()

    with pytest.raises(ValueError):
        await auth.change_password(db, user, "wrong-current", "newpassword1")

    await auth.change_password(db, user, "password123", "newpassword1")
    # 옛 비밀번호는 더 이상 안 되고, 새 비밀번호로 로그인된다.
    with pytest.raises(ValueError):
        await auth.login(db, "pwuser", "password123")
    access_token, _ = await auth.login(db, "pwuser", "newpassword1")
    assert decode_token(access_token, expected_type="access") == user.id


@pytest.mark.asyncio
async def test_change_password_rejected_for_kakao_only_account(db):
    auth = AuthService()
    kakao_user = User(kakao_id="kakao-only", nickname="카카오유저")
    db.add(kakao_user)
    await db.commit()

    with pytest.raises(ValueError):
        await auth.change_password(db, kakao_user, "anything", "newpassword1")


@pytest.mark.asyncio
async def test_signup_rejects_duplicate_username(db):
    auth = AuthService()
    await auth.signup(db, _signup_request(username="dupuser"))
    with pytest.raises(ValueError):
        await auth.signup(db, _signup_request(username="dupuser"))


@pytest.mark.asyncio
async def test_username_available(db):
    auth = AuthService()
    assert await auth.is_username_available(db, "freeusername") is True
    await auth.signup(db, _signup_request(username="freeusername"))
    assert await auth.is_username_available(db, "freeusername") is False


def test_invalid_username_format_rejected():
    with pytest.raises(Exception):
        _signup_request(username="a")  # 4자 미만
    with pytest.raises(Exception):
        _signup_request(username="한글아이디")


def test_phone_verification_token_rejects_wrong_type():
    from app.core.security import create_access_token

    with pytest.raises(TokenError):
        decode_phone_verification_token(create_access_token(1))
