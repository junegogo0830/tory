import asyncio
import logging
import time
from functools import lru_cache

from redis.asyncio import Redis

from ..core.config import settings

logger = logging.getLogger(__name__)

_CACHE_OP_TIMEOUT_SECONDS = 0.3

# Redis가 없을 때(로컬 개발 등)를 위한 프로세스 내 폴백 캐시.
# key -> (만료 시각(monotonic), value). 여러 워커 프로세스 간에는 공유되지
# 않으므로 프로덕션에서는 항상 실제 Redis가 우선이다 — 이건 어디까지나
# "Redis를 안 띄워도 로컬에서 캐싱 동작 자체는 확인할 수 있게" 하는 보조 수단.
_local_cache: dict[str, tuple[float, str]] = {}


@lru_cache
def get_redis() -> Redis:
    """지연 연결 Redis 클라이언트. 실제 명령 실행 전까지 연결을 시도하지 않는다."""
    return Redis.from_url(
        settings.redis_url,
        decode_responses=True,
        socket_connect_timeout=0.5,
        socket_timeout=0.5,
        retry_on_timeout=False,
    )


def _local_get(key: str) -> str | None:
    entry = _local_cache.get(key)
    if entry is None:
        return None
    expires_at, value = entry
    if expires_at < time.monotonic():
        del _local_cache[key]
        return None
    return value


def _local_set(key: str, value: str, *, ex: int) -> None:
    _local_cache[key] = (time.monotonic() + ex, value)


async def cache_get(key: str) -> str | None:
    """캐시 조회를 강하게 시간제한을 걸어 실행한다.

    Redis가 꺼져 있을 때(로컬 개발 등) redis-py의 내부 재시도/타임아웃 처리가
    동시 요청이 많으면 예상보다 오래 걸리는 걸 확인했다 — 여러 곳에서 동시에
    같은 Redis 클라이언트로 붙을 때 특히 그렇다. 클라이언트 자체의 타임아웃
    설정과 별개로, 호출부에서 한 번 더 강제로 짧게 끊어서 API 응답 전체가
    캐시 장애 때문에 느려지는 걸 막는다. Redis 자체가 없으면 프로세스 내
    폴백 캐시로 넘어간다 — 로컬 개발에서도 캐싱이 실제로 동작하게.
    """
    try:
        value = await asyncio.wait_for(get_redis().get(key), timeout=_CACHE_OP_TIMEOUT_SECONDS)
        if value is not None:
            return value
    except Exception:  # noqa: BLE001 — 캐시는 있으면 좋고 없어도 그만이다.
        # exc_info는 일부러 안 붙인다 — Redis 미기동은 로컬 개발에서 흔한 정상
        # 경로라 매번 전체 스택트레이스를 찍으면 진짜 에러를 찾기만 어려워진다.
        logger.debug("Redis GET skipped (unavailable/timeout) for key=%s", key)

    return _local_get(key)


async def cache_set(key: str, value: str, *, ex: int) -> None:
    _local_set(key, value, ex=ex)
    try:
        await asyncio.wait_for(get_redis().set(key, value, ex=ex), timeout=_CACHE_OP_TIMEOUT_SECONDS)
    except Exception:  # noqa: BLE001
        logger.debug("Redis SET skipped (unavailable/timeout) for key=%s", key)
