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

    sentiment_model_path: str = "./ml/serving/model.onnx"

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
