from functools import lru_cache

from redis.asyncio import Redis

from ..core.config import settings


@lru_cache
def get_redis() -> Redis:
    """지연 연결 Redis 클라이언트. 실제 명령 실행 전까지 연결을 시도하지 않는다."""
    return Redis.from_url(settings.redis_url, decode_responses=True)
