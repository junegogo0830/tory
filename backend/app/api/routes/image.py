import logging

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/image", tags=["image"])

# TourAPI(한국관광공사) 이미지 CDN(tong.visitkorea.or.kr)은 CORS 헤더를 전혀 안 보낸다
# (실측 확인: Origin 헤더를 보내도 Access-Control-Allow-Origin 없이 그냥 200을 준다).
# curl/httpx 같은 서버 간 호출은 CORS가 적용되지 않아 멀쩡히 받아지지만, Flutter Web의
# CanvasKit 렌더러는 캔버스에 이미지를 디코드하려면 CORS 허용이 필요해서 브라우저에서만
# 조용히 로드가 실패한다("사진 대신 카메라 아이콘/빨간 X"의 실제 원인).
# 서버가 대신 이미지를 받아 우리 도메인(CORSMiddleware가 허용)으로 재서빙해 우회한다.
_ALLOWED_HOST_SUFFIXES = ("visitkorea.or.kr",)


def _is_allowed(url: httpx.URL) -> bool:
    if url.scheme not in ("http", "https") or not url.host:
        return False
    return any(url.host == suffix or url.host.endswith(f".{suffix}") for suffix in _ALLOWED_HOST_SUFFIXES)


@router.get("/proxy")
async def proxy_image(url: str) -> Response:
    """외부 이미지를 서버가 대신 받아 CORS 허용 응답으로 재서빙한다.

    임의 호스트로 서버가 요청을 대신 보내주는(SSRF) 구멍이 되지 않도록, 실제로
    쓰는 TourAPI 이미지 CDN 도메인만 허용한다.
    """
    try:
        parsed = httpx.URL(url)
    except httpx.InvalidURL:
        raise HTTPException(status_code=400, detail="올바르지 않은 이미지 주소예요") from None

    if not _is_allowed(parsed):
        raise HTTPException(status_code=400, detail="허용되지 않은 이미지 호스트예요")

    try:
        async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client:
            response = await client.get(parsed)
            response.raise_for_status()
    except httpx.HTTPError:
        logger.exception("Image proxy fetch failed for url=%s", url)
        raise HTTPException(status_code=502, detail="이미지를 불러오지 못했어요") from None

    content_type = response.headers.get("content-type", "image/jpeg")
    return Response(
        content=response.content,
        media_type=content_type,
        headers={"Cache-Control": "public, max-age=86400"},
    )
