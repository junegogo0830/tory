from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .api.router import api_router
from .core.config import settings
from .core.logging import configure_logging

configure_logging()

if not settings.debug and settings.jwt_secret_key in ("", "dev-only-insecure-secret-change-me"):
    raise RuntimeError(
        "JWT_SECRET_KEY is unset in a non-debug environment. "
        "Generate one with `openssl rand -hex 32` and set it before deploying."
    )

app = FastAPI(title="Yetgil API", debug=settings.debug)

app.add_middleware(
    CORSMiddleware,
    # 인증은 쿠키가 아니라 JWT 베어러 토큰(헤더)만 쓰므로 origin을 전부 열어도
    # 자격증명이 새 나가지 않는다 — 프로덕션에서만 빈 리스트였던 게 버그였다
    # (배포된 서버가 브라우저 요청을 전부 막고 있었음, 카카오 웹 로그인 콜백
    # 교환 등에서 원인 불명의 무한 로딩으로 나타난다).
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)

# 커뮤니티 "추억 등록" 사진 정적 서빙. community_upload_dir은 uploads/community까지의
# 경로라 그 부모(uploads/)를 "/uploads"에 마운트해 "/uploads/community/<file>"로 접근한다.
_uploads_root = Path(settings.community_upload_dir).parent
_uploads_root.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=_uploads_root), name="uploads")
