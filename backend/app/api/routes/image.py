"""Bounded image cache: returning home must not download the same CDN asset again."""
import asyncio
import hashlib
import time
from collections import OrderedDict

import httpx
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import Response

router = APIRouter(prefix="/api/image", tags=["image"])
_ALLOWED_HOST_SUFFIXES = ("visitkorea.or.kr",)
_MAX_IMAGE_BYTES = 8 * 1024 * 1024
_MAX_CACHE_BYTES = 64 * 1024 * 1024
_cache: OrderedDict[str, tuple[float, bytes, str, str]] = OrderedDict()
_inflight: dict[str, asyncio.Task] = {}


def _is_allowed(url: httpx.URL) -> bool:
    return (url.scheme in ("http", "https") and not url.userinfo
            and url.port in (None, 80, 443)
            and any(url.host == h or url.host.endswith("." + h) for h in _ALLOWED_HOST_SUFFIXES))


async def _fetch_once(url: str) -> tuple[float, bytes, str, str]:
    async with httpx.AsyncClient(timeout=8, follow_redirects=False) as client:
        target = httpx.URL(url)
        for _ in range(4):
            if not _is_allowed(target):
                raise HTTPException(400, "허용되지 않은 이미지 호스트예요")
            async with client.stream("GET", target) as response:
                if response.is_redirect:
                    target = target.join(response.headers.get("location", ""))
                    continue
                response.raise_for_status()
                content_type = response.headers.get("content-type", "").split(";")[0]
                # TourAPI's CDN uses the nonstandard image/jpg alias for JPEG.
                if content_type.lower() in ("image/jpg", "image/pjpeg"):
                    content_type = "image/jpeg"
                if content_type not in ("image/jpeg", "image/png", "image/webp", "image/gif"):
                    raise HTTPException(502, "이미지 형식이 올바르지 않아요")
                data = bytearray()
                async for chunk in response.aiter_bytes():
                    data.extend(chunk)
                    if len(data) > _MAX_IMAGE_BYTES:
                        raise HTTPException(413, "이미지 크기가 너무 커요")
                raw = bytes(data)
                entry = (time.monotonic() + 86400, raw, content_type, '"' + hashlib.sha256(raw).hexdigest() + '"')
                _cache[url] = entry
                _cache.move_to_end(url)
                while sum(len(e[1]) for e in _cache.values()) > _MAX_CACHE_BYTES or len(_cache) > 256:
                    _cache.popitem(last=False)
                return entry
    raise HTTPException(502, "이미지 주소 이동이 너무 많아요")


async def _fetch(url: str) -> tuple[float, bytes, str, str]:
    """visitkorea.or.kr 쪽이 가끔 순간적으로 연결을 끊는 경우가 있어(TourAPI
    본 API에서도 같은 증상을 확인했다), 실패하면 짧게 대기 후 한 번 더 시도한다."""
    try:
        return await _fetch_once(url)
    except httpx.HTTPError:
        await asyncio.sleep(0.5)
        return await _fetch_once(url)


async def get_image(url: str) -> tuple[float, bytes, str, str]:
    cached = _cache.get(url)
    if cached and cached[0] > time.monotonic():
        _cache.move_to_end(url)
        return cached
    if url not in _inflight:
        if len(_inflight) >= 24:
            raise HTTPException(503, "사진을 준비하고 있어요. 잠시 후 다시 시도해주세요")
        task = asyncio.create_task(_fetch(url))
        _inflight[url] = task
        def finished(done):
            _inflight.pop(url, None)
            if not done.cancelled():
                done.exception()  # Retrieve errors even if the browser disconnected.
        task.add_done_callback(finished)
    try:
        return await asyncio.shield(_inflight[url])
    except (httpx.HTTPError, HTTPException):
        if cached:
            return cached
        raise


@router.get("/proxy")
async def proxy_image(url: str, request: Request) -> Response:
    try:
        parsed = httpx.URL(url)
    except httpx.InvalidURL:
        raise HTTPException(400, "올바르지 않은 이미지 주소예요") from None
    if not _is_allowed(parsed):
        raise HTTPException(400, "허용되지 않은 이미지 호스트예요")
    try:
        _, data, content_type, etag = await get_image(str(parsed))
    except httpx.HTTPError:
        raise HTTPException(502, "이미지를 불러오지 못했어요") from None
    headers = {"Cache-Control": "public, max-age=86400, stale-if-error=604800", "ETag": etag}
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers=headers)
    return Response(data, media_type=content_type, headers=headers)
