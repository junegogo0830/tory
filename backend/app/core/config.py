from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# backend/app/core/config.py -> repo root
_REPO_ROOT = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    env: str = "development"
    debug: bool = True

    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_user: str = "yetgil"
    postgres_password: str = "changeme"
    postgres_db: str = "yetgil"
    database_url: str = "postgresql+asyncpg://yetgil:changeme@localhost:5432/yetgil"

    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_url: str = "redis://localhost:6379/0"

    tour_api_key: str = ""
    naver_news_client_id: str = ""
    naver_news_client_secret: str = ""
    kakao_map_js_key: str = ""
    kakao_rest_api_key: str = ""
    anthropic_api_key: str = ""
    openweather_api_key: str = ""

    sentiment_model_path: str = "./ml/serving/model.onnx"

    # 커뮤니티 "추억 등록" 사진 저장 경로. 클라우드 스토리지 대신 로컬 디스크에 저장하고
    # StaticFiles로 서빙한다 — VM 디스크는 영구적이라 지금 단계엔 충분하고, 나중에
    # 오브젝트 스토리지로 옮길 때도 이 경로 설정만 바꾸면 되게 격리해뒀다.
    community_upload_dir: str = str(_REPO_ROOT / "backend" / "uploads" / "community")
    community_upload_max_bytes: int = 8 * 1024 * 1024

    # 개발 편의를 위한 기본값이지 실제 값이 아니다. 배포 전 반드시 .env에서
    # `openssl rand -hex 32`로 생성한 값으로 덮어써야 한다.
    jwt_secret_key: str = "dev-only-insecure-secret-change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60
    jwt_refresh_token_expire_days: int = 30

    model_config = SettingsConfigDict(
        env_file=str(_REPO_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
