from fastapi.testclient import TestClient

from app.core.security import create_access_token
from app.main import app

client = TestClient(app)


def test_refresh_rejects_garbage_token() -> None:
    response = client.post("/api/auth/refresh", json={"refresh_token": "not-a-real-token"})
    assert response.status_code == 401


def test_refresh_rejects_access_token_used_as_refresh_token() -> None:
    # 토큰 타입 혼동 방지: access 토큰으로 refresh를 시도하면 거부돼야 한다.
    access_token = create_access_token(user_id=1)
    response = client.post("/api/auth/refresh", json={"refresh_token": access_token})
    assert response.status_code == 401


def test_kakao_login_rejects_missing_body() -> None:
    response = client.post("/api/auth/kakao/login", json={})
    assert response.status_code == 422


def test_saved_locations_endpoint_requires_auth() -> None:
    response = client.post("/api/profile/saved-locations/suncheon-jeonpo")
    assert response.status_code == 401


def test_completed_courses_endpoint_requires_auth() -> None:
    response = client.post("/api/profile/completed-courses/c1")
    assert response.status_code == 401


def test_expired_access_token_is_rejected() -> None:
    import datetime

    import jwt

    from app.core.config import settings

    expired_payload = {
        "sub": "1",
        "type": "access",
        "iat": datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=2),
        "exp": datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=1),
    }
    expired_token = jwt.encode(expired_payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)

    response = client.get("/api/profile", headers={"Authorization": f"Bearer {expired_token}"})
    assert response.status_code == 401
