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


class NaverWebLoginRequest(BaseModel):
    """네이버 로그인은 웹 리다이렉트 방식만 지원한다(카카오 웹 로그인과 같은
    패턴) — 프론트가 네이버 인증 서버로 리다이렉트한 뒤 돌려받은 code/state를
    여기로 보낸다."""

    code: str
    # CSRF 방지용 — 프론트가 authorize 요청 때 만들어 보낸 값과 정확히 같아야
    # 한다(네이버가 콜백에 그대로 돌려준다).
    state: str
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
    username: str
    password: str = Field(min_length=8, max_length=72)
    # 필수 약관 — 회원가입 화면에서 둘 다 체크해야 제출 버튼이 활성화된다.
    agree_terms: bool
    agree_privacy: bool
    # 선택 약관 — 기본값 False.
    agree_marketing: bool = False
    # phone/verify-code로 받은 토큰 — 선택 입력. NCP SENS 발신번호가 아직
    # 승인 전이라 실제 문자 대신 서버 로그로만 인증번호가 남는 상태라(SMS
    # 서비스는 사업자 등록/발신번호 사전등록이 필요), 회원가입 자체를 막지
    # 않도록 필수로 만들지 않았다 — 승인되면 그대로 실동작한다.
    phone_verification_token: str | None = None

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
