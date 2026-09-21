import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.security import (
    TokenError,
    create_access_token,
    create_refresh_token,
    decode_phone_verification_token,
    hash_password,
    verify_password,
)
from ..db.models import User
from ..models.auth import SignupRequest
from .kakao_auth import KakaoAuthService
from .naver_auth import NaverAuthService
from .phone_verification import PhoneVerificationService


class AuthService:
    def __init__(
        self,
        kakao_auth_service: KakaoAuthService | None = None,
        naver_auth_service: NaverAuthService | None = None,
        phone_verification_service: PhoneVerificationService | None = None,
    ) -> None:
        self._kakao_auth_service = kakao_auth_service or KakaoAuthService()
        self._naver_auth_service = naver_auth_service or NaverAuthService()
        self._phone_verification_service = phone_verification_service or PhoneVerificationService()

    async def is_username_available(self, db: AsyncSession, username: str) -> bool:
        existing = await db.scalar(select(User).where(User.username == username))
        return existing is None

    async def signup(self, db: AsyncSession, body: SignupRequest) -> tuple[str, str]:
        """자체 회원가입 — 약관 동의를 확인한 뒤 유저를 만들고 옛길 자체 JWT 쌍을
        발급한다.

        휴대폰 인증은 SMS 설정 여부와 관계없이 필수다.
        발송 설정이 없거나 발송에 실패하면 인증 없이 가입할 수 없다.
        """
        if not body.agree_terms or not body.agree_privacy:
            raise ValueError("필수 약관에 동의해주세요")

        if await db.scalar(select(User).where(User.username == body.username)) is not None:
            raise ValueError("이미 사용 중인 아이디예요")

        if not body.phone_verification_token:
            raise ValueError("휴대폰 인증을 완료해주세요")

        phone_number: str | None = None
        if body.phone_verification_token:
            try:
                phone_number = decode_phone_verification_token(body.phone_verification_token)
            except TokenError:
                raise ValueError("휴대폰 인증이 만료됐어요. 인증번호를 다시 받아주세요") from None
            if await db.scalar(select(User).where(User.phone_number == phone_number)) is not None:
                raise ValueError("이미 가입에 사용된 휴대폰 번호예요")

        now = datetime.datetime.now(datetime.timezone.utc)
        user = User(
            username=body.username,
            password_hash=hash_password(body.password),
            # 닉네임 기본값은 아이디 — 가입 화면을 짧게 유지하고, 원하면 프로필
            # 편집 화면에서 바로 바꿀 수 있다(edit_profile_screen.dart).
            nickname=body.username,
            phone_number=phone_number,
            terms_agreed_at=now,
            privacy_agreed_at=now,
            marketing_agreed=body.agree_marketing,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

        return create_access_token(user.id), create_refresh_token(user.id)

    async def change_password(
        self, db: AsyncSession, user: User, current_password: str, new_password: str
    ) -> None:
        if user.password_hash is None:
            raise ValueError("카카오 로그인 계정은 비밀번호를 변경할 수 없어요")
        if not verify_password(current_password, user.password_hash):
            raise ValueError("현재 비밀번호가 올바르지 않아요")
        user.password_hash = hash_password(new_password)
        await db.commit()

    async def login(self, db: AsyncSession, username: str, password: str) -> tuple[str, str]:
        user = await db.scalar(select(User).where(User.username == username))
        if user is None or user.password_hash is None or not verify_password(password, user.password_hash):
            raise ValueError("아이디 또는 비밀번호가 올바르지 않아요")
        return create_access_token(user.id), create_refresh_token(user.id)

    async def login_with_kakao_code(self, db: AsyncSession, code: str, redirect_uri: str) -> tuple[str, str]:
        """웹 로그인 전용 — authorization code를 카카오 액세스 토큰으로 먼저 교환한
        뒤, 네이티브 앱과 같은 login_with_kakao 경로를 그대로 탄다."""
        access_token = await self._kakao_auth_service.exchange_code_for_token(code, redirect_uri)
        return await self.login_with_kakao(db, access_token)

    async def login_with_kakao(self, db: AsyncSession, kakao_access_token: str) -> tuple[str, str]:
        """카카오 액세스 토큰을 검증하고, 유저를 upsert한 뒤 옛길 자체 JWT 쌍을 발급한다."""
        profile = await self._kakao_auth_service.fetch_profile(kakao_access_token)

        result = await db.execute(select(User).where(User.kakao_id == profile.kakao_id))
        user = result.scalar_one_or_none()

        if user is None:
            user = User(
                kakao_id=profile.kakao_id,
                nickname=profile.nickname,
                profile_image_url=profile.profile_image_url,
            )
            db.add(user)
        else:
            user.nickname = profile.nickname
            user.profile_image_url = profile.profile_image_url

        await db.commit()
        await db.refresh(user)

        return create_access_token(user.id), create_refresh_token(user.id)

    async def login_with_naver_code(self, db: AsyncSession, code: str, state: str, redirect_uri: str) -> tuple[str, str]:
        """웹 로그인 전용 — authorization code를 네이버 액세스 토큰으로 먼저
        교환한 뒤, login_with_naver로 이어간다(login_with_kakao_code와 같은 구조)."""
        access_token = await self._naver_auth_service.exchange_code_for_token(code, state, redirect_uri)
        return await self.login_with_naver(db, access_token)

    async def login_with_naver(self, db: AsyncSession, naver_access_token: str) -> tuple[str, str]:
        """네이버 액세스 토큰을 검증하고, 유저를 upsert한 뒤 옛길 자체 JWT 쌍을 발급한다."""
        profile = await self._naver_auth_service.fetch_profile(naver_access_token)

        result = await db.execute(select(User).where(User.naver_id == profile.naver_id))
        user = result.scalar_one_or_none()

        if user is None:
            user = User(
                naver_id=profile.naver_id,
                nickname=profile.nickname,
                profile_image_url=profile.profile_image_url,
            )
            db.add(user)
        else:
            user.nickname = profile.nickname
            user.profile_image_url = profile.profile_image_url

        await db.commit()
        await db.refresh(user)

        return create_access_token(user.id), create_refresh_token(user.id)

    async def refresh(self, db: AsyncSession, user_id: int) -> str:
        result = await db.execute(select(User).where(User.id == user_id))
        if result.scalar_one_or_none() is None:
            raise ValueError("user no longer exists")
        return create_access_token(user_id)
