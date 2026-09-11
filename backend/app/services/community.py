import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..db.models import CommunityPost, User
from ..models.community import CommunityPostResponse
from .kakao_local import KakaoLocalService

_ALLOWED_CONTENT_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}


class CommunityService:
    """사용자가 직접 올리는 "그 시절 추억" 사진 게시물 — TourAPI처럼 외부에서 실시간으로
    불러오는 게 아니라 우리 DB/디스크가 소스 오브 트루스인 첫 콘텐츠 타입이다."""

    def __init__(self, kakao_local_service: KakaoLocalService | None = None) -> None:
        self._kakao_local_service = kakao_local_service or KakaoLocalService()

    async def region_by_coords(self, latitude: float, longitude: float) -> str | None:
        return await self._kakao_local_service.reverse_geocode(latitude, longitude)

    async def set_home_region(self, db: AsyncSession, user: User, region: str) -> None:
        user.home_region = region
        await db.commit()

    async def create_post(
        self,
        db: AsyncSession,
        user: User,
        *,
        region: str,
        file: UploadFile,
        location_id: str | None = None,
        caption: str | None = None,
        memory_year: int | None = None,
    ) -> CommunityPostResponse:
        photo_path = await self._save_photo(file)
        post = CommunityPost(
            user_id=user.id,
            region=region,
            location_id=location_id,
            photo_path=photo_path,
            caption=caption,
            memory_year=memory_year,
        )
        db.add(post)
        await db.commit()
        await db.refresh(post)
        return self._to_response(post, author_nickname=user.nickname)

    async def list_posts(self, db: AsyncSession, *, region: str, limit: int = 20, offset: int = 0) -> list[CommunityPostResponse]:
        result = await db.execute(
            select(CommunityPost, User.nickname)
            .join(User, User.id == CommunityPost.user_id)
            .where(CommunityPost.region == region)
            .order_by(desc(CommunityPost.created_at))
            .limit(limit)
            .offset(offset)
        )
        return [self._to_response(post, author_nickname=nickname) for post, nickname in result.all()]

    async def _save_photo(self, file: UploadFile) -> str:
        extension = _ALLOWED_CONTENT_TYPES.get(file.content_type or "")
        if extension is None:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="jpg/png/webp 사진만 올릴 수 있어요"
            )

        contents = await file.read()
        if len(contents) > settings.community_upload_max_bytes:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"사진은 {settings.community_upload_max_bytes // (1024 * 1024)}MB 이하만 올릴 수 있어요",
            )

        upload_dir = Path(settings.community_upload_dir)
        upload_dir.mkdir(parents=True, exist_ok=True)
        filename = f"{uuid.uuid4().hex}{extension}"
        (upload_dir / filename).write_bytes(contents)
        return filename

    @staticmethod
    def _to_response(post: CommunityPost, *, author_nickname: str) -> CommunityPostResponse:
        return CommunityPostResponse(
            id=post.id,
            author_nickname=author_nickname,
            region=post.region,
            location_id=post.location_id,
            photo_url=f"/uploads/community/{post.photo_path}",
            caption=post.caption,
            memory_year=post.memory_year,
            created_at=post.created_at,
        )
