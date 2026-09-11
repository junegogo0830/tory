import httpx
from pydantic import BaseModel


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
