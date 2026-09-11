import datetime
from typing import Literal

import jwt

from .config import settings


class TokenError(Exception):
    pass


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
