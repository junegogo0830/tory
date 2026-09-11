from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.security import TokenError, decode_token
from ...db.postgres import get_db_session
from ...models.auth import AccessTokenResponse, KakaoLoginRequest, RefreshRequest, TokenResponse
from ...services.auth import AuthService
from ...services.kakao_auth import KakaoAuthError

router = APIRouter(prefix="/api/auth", tags=["auth"])
_auth_service = AuthService()


@router.post("/kakao/login", response_model=TokenResponse)
async def login_with_kakao(
    body: KakaoLoginRequest, db: AsyncSession = Depends(get_db_session)
) -> TokenResponse:
    try:
        access_token, refresh_token = await _auth_service.login_with_kakao(db, body.access_token)
    except KakaoAuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Kakao access token") from exc

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
