from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.security import TokenError, decode_token
from ...db.postgres import get_db_session
from ...models.auth import (
    AccessTokenResponse,
    KakaoLoginRequest,
    KakaoWebLoginRequest,
    LoginRequest,
    PhoneVerifiedResponse,
    RefreshRequest,
    SendPhoneCodeRequest,
    SignupRequest,
    TokenResponse,
    UsernameAvailableResponse,
    VerifyPhoneCodeRequest,
)
from ...services.auth import AuthService
from ...services.kakao_auth import KakaoAuthError
from ...services.phone_verification import PhoneVerificationService

router = APIRouter(prefix="/api/auth", tags=["auth"])
_auth_service = AuthService()
_phone_verification_service = PhoneVerificationService()


@router.get("/phone/required")
async def is_phone_verification_required() -> dict[str, bool]:
    """NCP SENS 발신번호가 승인돼 실제로 문자를 보낼 수 있을 때만 true —
    회원가입 화면이 이 값으로 휴대폰 인증을 필수/선택으로 표시한다."""
    return {"required": _phone_verification_service.is_live}


@router.post("/phone/send-code", status_code=status.HTTP_204_NO_CONTENT)
async def send_phone_verification_code(
    body: SendPhoneCodeRequest, db: AsyncSession = Depends(get_db_session)
) -> None:
    await _phone_verification_service.send_code(db, body.phone_number)


@router.post("/phone/verify-code", response_model=PhoneVerifiedResponse)
async def verify_phone_verification_code(
    body: VerifyPhoneCodeRequest, db: AsyncSession = Depends(get_db_session)
) -> PhoneVerifiedResponse:
    token = await _phone_verification_service.verify_code(db, body.phone_number, body.code)
    return PhoneVerifiedResponse(phone_verification_token=token)


@router.get("/username-available", response_model=UsernameAvailableResponse)
async def check_username_available(
    username: str, db: AsyncSession = Depends(get_db_session)
) -> UsernameAvailableResponse:
    return UsernameAvailableResponse(available=await _auth_service.is_username_available(db, username))


@router.post("/signup", response_model=TokenResponse)
async def signup(body: SignupRequest, db: AsyncSession = Depends(get_db_session)) -> TokenResponse:
    try:
        access_token, refresh_token = await _auth_service.signup(db, body)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db_session)) -> TokenResponse:
    try:
        access_token, refresh_token = await _auth_service.login(db, body.username, body.password)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/kakao/login", response_model=TokenResponse)
async def login_with_kakao(
    body: KakaoLoginRequest, db: AsyncSession = Depends(get_db_session)
) -> TokenResponse:
    try:
        access_token, refresh_token = await _auth_service.login_with_kakao(db, body.access_token)
    except KakaoAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Kakao access token") from exc

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/kakao/login-web", response_model=TokenResponse)
async def login_with_kakao_web(
    body: KakaoWebLoginRequest, db: AsyncSession = Depends(get_db_session)
) -> TokenResponse:
    """웹 전용 — kakao_flutter_sdk_user는 web에서 로그인 메서드를 전혀 지원하지
    않아, 프론트가 직접 카카오 인증 서버로 리다이렉트하고 돌려받은 authorization
    code로 로그인한다(AuthRepository.completeKakaoWebLogin 참고)."""
    try:
        access_token, refresh_token = await _auth_service.login_with_kakao_code(db, body.code, body.redirect_uri)
    except KakaoAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Kakao authorization code") from exc

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=AccessTokenResponse)
async def refresh_access_token(
    body: RefreshRequest, db: AsyncSession = Depends(get_db_session)
) -> AccessTokenResponse:
    try:
        user_id = decode_token(body.refresh_token, expected_type="refresh")
    except TokenError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token") from exc

    try:
        access_token = await _auth_service.refresh(db, user_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User no longer exists") from exc

    return AccessTokenResponse(access_token=access_token)
