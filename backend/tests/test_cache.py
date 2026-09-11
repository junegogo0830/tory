import pytest

from app.db.redis import cache_get, cache_set


@pytest.mark.asyncio
async def test_cache_roundtrips_via_local_fallback_without_redis() -> None:
    # 이 테스트 환경엔 Redis가 없으므로, cache_set 후 cache_get이 여전히 값을
    # 돌려준다면 프로세스 내 폴백 캐시가 실제로 동작하고 있다는 뜻이다.
    await cache_set("test:roundtrip", "hello", ex=60)
    assert await cache_get("test:roundtrip") == "hello"


@pytest.mark.asyncio
async def test_cache_get_returns_none_for_missing_key() -> None:
    assert await cache_get("test:definitely-not-set") is None
