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

    # SENS 발송 설정. 하나라도 비어 있으면 발송에 실패하며 인증을 우회할 수 없다.
    ncp_access_key: str = ""
    ncp_secret_key: str = ""
    ncp_sens_service_id: str = ""
    # SENS에 사전 등록한 발신번호. 하이픈 없이 숫자만(예: "01012345678").
    ncp_sens_sender_number: str = ""
    anthropic_api_key: str = ""
    openweather_api_key: str = ""

    sentiment_model_path: str = "./ml/serving/model.onnx"

    # 커뮤니티 "추억 등록" 사진 저장 경로. 클라우드 스토리지 대신 로컬 디스크에 저장하고
    # StaticFiles로 서빙한다 — VM 디스크는 영구적이라 지금 단계엔 충분하고, 나중에
    # 오브젝트 스토리지로 옮길 때도 이 경로 설정만 바꾸면 되게 격리해뒀다.
    community_upload_dir: str = str(_REPO_ROOT / "backend" / "uploads" / "community")
    community_upload_max_bytes: int = 8 * 1024 * 1024

    # 프로필 사진 업로드 — 같은 "/uploads" StaticFiles 마운트 아래 별도 하위 폴더로
    # 서빙된다(main.py가 community_upload_dir의 부모를 "/uploads"에 마운트하므로
    # 형제 폴더인 이 경로도 자동으로 "/uploads/profile/<file>"로 서빙된다).
    profile_upload_dir: str = str(_REPO_ROOT / "backend" / "uploads" / "profile")
    profile_upload_max_bytes: int = 5 * 1024 * 1024

    # 코스 커스텀 장소에 직접 등록하는 사진 — 같은 "/uploads" 마운트 아래 형제 폴더.
    custom_course_upload_dir: str = str(_REPO_ROOT / "backend" / "uploads" / "custom-course")
    custom_course_upload_max_bytes: int = 8 * 1024 * 1024

    # 비어 있으면(로컬 개발) 사진을 로컬 디스크에 저장한다. 배포 환경(Cloud Run)은
    # 로컬 디스크가 인스턴스마다 별개고 재시작되면 사라지는 휘발성 저장소라,
    # 여기에 실제 버킷 이름을 채우면 photo_upload.py가 Google Cloud Storage에
    # 영구 저장하도록 바뀐다.
    gcs_bucket_name: str = ""

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
