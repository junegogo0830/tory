from pydantic import BaseModel


class KakaoLoginRequest(BaseModel):
    # Flutter 앱의 카카오 로그인 SDK가 발급한 액세스 토큰. 백엔드는 이 토큰을
    # 카카오 서버에 되물어(GET /v2/user/me) 진위와 사용자 정보를 확인한다.
    access_token: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
