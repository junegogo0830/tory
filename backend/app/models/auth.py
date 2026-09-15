import re

from pydantic import BaseModel, Field, field_validator

_USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{4,20}$")


class KakaoLoginRequest(BaseModel):
    # Flutter 앱의 카카오 로그인 SDK가 발급한 액세스 토큰. 백엔드는 이 토큰을
    # 카카오 서버에 되물어(GET /v2/user/me) 진위와 사용자 정보를 확인한다.
    access_token: str


class KakaoWebLoginRequest(BaseModel):
    """웹은 카카오 로그인 SDK의 로그인 메서드를 전혀 지원하지 않아(kakao_flutter_sdk_user
    2.0.1 — loginWithKakaoTalk/Account/새 동의 전부 kIsWeb이면 예외) 프론트가 직접
    카카오 인증 서버로 리다이렉트한 뒤 돌려받은 authorization code를 여기로 보낸다.
    백엔드가 이 code를 카카오 토큰으로 교환(exchange_code_for_token)한 뒤엔
    기존 access_token 검증 로직(login_with_kakao)을 그대로 재사용한다."""

    code: str
    # 카카오에 요청했던 redirect_uri와 정확히 같아야 한다(카카오가 검증) — 프론트가
    # authorize() 호출 때 쓴 값을 그대로 다시 보낸다.
    redirect_uri: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class SendPhoneCodeRequest(BaseModel):
    phone_number: str


class VerifyPhoneCodeRequest(BaseModel):
    phone_number: str
    code: str = Field(min_length=6, max_length=6)


class PhoneVerifiedResponse(BaseModel):
    # 회원가입 요청에 그대로 실어 보내는 짧은 유효기간(10분) 토큰.
    phone_verification_token: str


class UsernameAvailableResponse(BaseModel):
    available: bool


class SignupRequest(BaseModel):
    # 휴대폰 본인확인은 뺐다 — SMS 발송 업체(NCP SENS 등)가 전부 사업자 등록을
    # 요구해서 개인 프로젝트 단계에서는 막혀 있다. phone/send-code, verify-code
    # 엔드포인트와 PhoneVerificationService는 나중에 업체를 구해 다시 연결할 수
    # 있게 그대로 남겨뒀다(services/phone_verification.py 참고).
    username: str
    password: str = Field(min_length=8, max_length=72)
    # 필수 약관 — 회원가입 화면에서 둘 다 체크해야 제출 버튼이 활성화된다.
    agree_terms: bool
    agree_privacy: bool
    # 선택 약관 — 기본값 False.
    agree_marketing: bool = False

    @field_validator("username")
    @classmethod
    def valid_username(cls, value: str) -> str:
        if not _USERNAME_RE.match(value):
            raise ValueError("아이디는 영문/숫자/밑줄(_) 4~20자여야 해요")
        return value


class LoginRequest(BaseModel):
    username: str
    password: str


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=72)
