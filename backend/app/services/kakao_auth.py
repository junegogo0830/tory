import httpx
from pydantic import BaseModel

from ..core.config import settings


class KakaoProfile(BaseModel):
    kakao_id: str
    nickname: str
    profile_image_url: str | None = None


class KakaoAuthError(Exception):
    pass


class KakaoAuthService:
    """Flutter 앱(카카오 로그인 SDK)이 발급받은 카카오 액세스 토큰을 검증한다.

    백엔드는 카카오 REST API 키로 직접 로그인하지 않는다 — 로그인 자체는 클라이언트의
    카카오 SDK가 수행하고, 백엔드는 그 결과로 받은 access_token이 진짜 카카오 토큰인지,
    어떤 사용자인지를 카카오 서버에 물어 확인만 한다.
    """

    _USER_INFO_URL = "https://kapi.kakao.com/v2/user/me"
    _TOKEN_URL = "https://kauth.kakao.com/oauth/token"

    async def exchange_code_for_token(self, code: str, redirect_uri: str) -> str:
        """웹 로그인 전용 — 프론트가 카카오 인증 서버 리다이렉트로 받은 authorization
        code를 카카오 액세스 토큰으로 교환한다.

        client_id는 반드시 프론트가 authorize()를 호출할 때 쓴 것과 같은 종류의 앱
        키여야 한다(카카오가 종류까지 대조한다) — 프론트 웹 로그인은 JavaScript 키로
        authorize()를 호출하므로, 여기서도 네이티브 앱이 쓰는 REST API 키가 아니라
        같은 JavaScript 키(kakao_map_js_key — 카카오맵 JS SDK와 앱 안에서 동일한 키를
        공유한다)를 써야 한다.
        """
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                self._TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "client_id": settings.kakao_map_js_key,
                    "redirect_uri": redirect_uri,
                    "code": code,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

        if response.status_code != 200:
            raise KakaoAuthError(f"Kakao code exchange failed: {response.status_code} {response.text}")

        return response.json()["access_token"]

    async def fetch_profile(self, kakao_access_token: str) -> KakaoProfile:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(
                self._USER_INFO_URL,
                headers={"Authorization": f"Bearer {kakao_access_token}"},
            )

        if response.status_code != 200:
            raise KakaoAuthError(f"Kakao token verification failed: {response.status_code} {response.text}")

        body = response.json()
        kakao_account = body.get("kakao_account", {})
        profile = kakao_account.get("profile", {})

        return KakaoProfile(
            kakao_id=str(body["id"]),
            nickname=profile.get("nickname") or "옛길 사용자",
            profile_image_url=profile.get("profile_image_url"),
        )
