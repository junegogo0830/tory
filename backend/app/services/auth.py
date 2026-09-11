from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.security import create_access_token, create_refresh_token
from ..db.models import User
from .kakao_auth import KakaoAuthService


class AuthService:
    def __init__(self, kakao_auth_service: KakaoAuthService | None = None) -> None:
        self._kakao_auth_service = kakao_auth_service or KakaoAuthService()

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

    async def refresh(self, db: AsyncSession, user_id: int) -> str:
        result = await db.execute(select(User).where(User.id == user_id))
        if result.scalar_one_or_none() is None:
            raise ValueError("user no longer exists")
        return create_access_token(user_id)
