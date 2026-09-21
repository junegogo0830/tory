import httpx
from pydantic import BaseModel

from ..core.config import settings


class NaverProfile(BaseModel):
    naver_id: str
    nickname: str
    profile_image_url: str | None = None


class NaverAuthError(Exception):
    pass


class NaverAuthService:
    """네이버 로그인 — 카카오 웹 로그인과 같은 방식(리다이렉트 + authorization
    code 교환)만 지원한다. 프론트가 네이버 인증 서버로 리다이렉트하고 돌려받은
    code를 여기서 네이버 액세스 토큰으로 교환한 뒤, 그 토큰으로 프로필을 조회한다.
    """

    _TOKEN_URL = "https://nid.naver.com/oauth2.0/token"
    _USER_INFO_URL = "https://openapi.naver.com/v1/nid/me"

    async def exchange_code_for_token(self, code: str, state: str, redirect_uri: str) -> str:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                self._TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "client_id": settings.naver_login_client_id,
                    "client_secret": settings.naver_login_client_secret,
                    "redirect_uri": redirect_uri,
                    "code": code,
                    "state": state,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

        body = response.json()
        if response.status_code != 200 or "access_token" not in body:
            raise NaverAuthError(f"Naver code exchange failed: {response.status_code} {response.text}")

        return body["access_token"]

    async def fetch_profile(self, naver_access_token: str) -> NaverProfile:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(
                self._USER_INFO_URL,
                headers={"Authorization": f"Bearer {naver_access_token}"},
            )

        if response.status_code != 200:
            raise NaverAuthError(f"Naver token verification failed: {response.status_code} {response.text}")

        body = response.json()
        if body.get("resultcode") != "00":
            raise NaverAuthError(f"Naver profile lookup failed: {body}")

        profile = body.get("response", {})

        return NaverProfile(
            naver_id=str(profile["id"]),
            nickname=profile.get("nickname") or "옛길 사용자",
            profile_image_url=profile.get("profile_image"),
        )
