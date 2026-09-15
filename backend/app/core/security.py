import datetime
from typing import Literal

import bcrypt
import jwt

from .config import settings


class TokenError(Exception):
    pass


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def _create_token(user_id: int, token_type: Literal["access", "refresh"], expires_delta: datetime.timedelta) -> str:
    now = datetime.datetime.now(datetime.timezone.utc)
    payload = {
        "sub": str(user_id),
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: int) -> str:
    return _create_token(
        user_id, "access", datetime.timedelta(minutes=settings.jwt_access_token_expire_minutes)
    )


def create_refresh_token(user_id: int) -> str:
    return _create_token(
        user_id, "refresh", datetime.timedelta(days=settings.jwt_refresh_token_expire_days)
    )


def decode_token(token: str, expected_type: Literal["access", "refresh"]) -> int:
    """토큰을 검증하고 user_id를 반환한다. 무효하면 TokenError."""
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except jwt.PyJWTError as exc:
        raise TokenError(str(exc)) from exc

    if payload.get("type") != expected_type:
        raise TokenError(f"expected {expected_type} token, got {payload.get('type')}")

    try:
        return int(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise TokenError("invalid subject claim") from exc


_PHONE_VERIFIED_TOKEN_TYPE = "phone_verified"
_PHONE_VERIFIED_TOKEN_TTL_MINUTES = 10


def create_phone_verification_token(phone_number: str) -> str:
    """휴대폰 인증번호 검증 성공 직후에만 발급한다 — 회원가입 요청이 이 토큰을
    같이 보내야 "그 번호를 방금 실제로 인증했음"을 증명한 것으로 인정한다.
    access/refresh 토큰과 subject 타입(전화번호 문자열 vs 유저 id)이 달라
    _create_token/decode_token을 그대로 못 쓴다."""
    now = datetime.datetime.now(datetime.timezone.utc)
    payload = {
        "sub": phone_number,
        "type": _PHONE_VERIFIED_TOKEN_TYPE,
        "iat": now,
        "exp": now + datetime.timedelta(minutes=_PHONE_VERIFIED_TOKEN_TTL_MINUTES),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_phone_verification_token(token: str) -> str:
    """토큰을 검증하고 인증된 전화번호를 반환한다. 무효/만료면 TokenError."""
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except jwt.PyJWTError as exc:
        raise TokenError(str(exc)) from exc

    if payload.get("type") != _PHONE_VERIFIED_TOKEN_TYPE:
        raise TokenError(f"expected {_PHONE_VERIFIED_TOKEN_TYPE} token, got {payload.get('type')}")

    sub = payload.get("sub")
    if not isinstance(sub, str) or not sub:
        raise TokenError("invalid subject claim")
    return sub
