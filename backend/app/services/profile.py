from fastapi import UploadFile
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..db.models import CommunityPost, CompletedCourse, SavedLocation, User, UserCourse
from ..models.course import CourseResponse
from ..models.profile import MyMemoryResponse, ProfileResponse, SavedLocationSummary
from .photo_upload import save_uploaded_photo
from .tourapi import TourApiService


class ProfileService:
    def __init__(self, tour_api_service: TourApiService | None = None) -> None:
        self._tour_api_service = tour_api_service or TourApiService()

    async def get_profile(self, db: AsyncSession, user: User) -> ProfileResponse:
        saved_rows = await db.execute(
            select(SavedLocation.location_id).where(SavedLocation.user_id == user.id)
        )
        location_ids = [row[0] for row in saved_rows.all()]

        # 저장 시점 이후 TourAPI 쪽에서 장소가 삭제됐을 수 있어 None은 걸러낸다.
        locations = [await self._tour_api_service.get_location_by_id(lid) for lid in location_ids]
        saved_locations = [
            SavedLocationSummary(id=loc.id, name=loc.name, region=loc.region) for loc in locations if loc is not None
        ]

        completed_count_row = await db.execute(
            select(func.count()).select_from(CompletedCourse).where(CompletedCourse.user_id == user.id)
        )
        completed_count = completed_count_row.scalar_one()

        memory_count_row = await db.execute(
            select(func.count()).select_from(CommunityPost).where(CommunityPost.user_id == user.id)
        )
        memory_count = memory_count_row.scalar_one()

        return ProfileResponse(
            display_name=user.nickname,
            tagline="나의 추억 여행을 기록하고 있어요",
            profile_image_url=user.profile_image_url,
            saved_locations_count=len(saved_locations),
            completed_courses_count=completed_count,
            memory_photo_count=memory_count,
            saved_locations=saved_locations,
            home_region=user.home_region,
        )

    async def save_location(self, db: AsyncSession, user: User, location_id: str) -> None:
        existing = await db.execute(
            select(SavedLocation).where(SavedLocation.user_id == user.id, SavedLocation.location_id == location_id)
        )
        if existing.scalar_one_or_none() is not None:
            return
        db.add(SavedLocation(user_id=user.id, location_id=location_id))
        await db.commit()

    async def unsave_location(self, db: AsyncSession, user: User, location_id: str) -> None:
        existing = await db.execute(
            select(SavedLocation).where(SavedLocation.user_id == user.id, SavedLocation.location_id == location_id)
        )
        row = existing.scalar_one_or_none()
        if row is not None:
            await db.delete(row)
            await db.commit()

    async def complete_course(self, db: AsyncSession, user: User, course_id: str) -> None:
        existing = await db.execute(
            select(CompletedCourse).where(
                CompletedCourse.user_id == user.id, CompletedCourse.course_id == course_id
            )
        )
        if existing.scalar_one_or_none() is not None:
            return
        db.add(CompletedCourse(user_id=user.id, course_id=course_id))
        await db.commit()

    async def get_memories(self, db: AsyncSession, user: User, *, limit: int = 30, offset: int = 0) -> list[MyMemoryResponse]:
        """"사진으로 남긴 추억" — 내가 쓴 글 중 사진이 있는 것만, 게시판 무관 최신순."""
        rows = await db.execute(
            select(CommunityPost)
            .where(CommunityPost.user_id == user.id, CommunityPost.photo_path.is_not(None))
            .order_by(desc(CommunityPost.created_at), desc(CommunityPost.id))
            .limit(limit)
            .offset(offset)
        )
        return [
            MyMemoryResponse(
                id=post.id,
                region=post.region,
                board=post.board,
                title=post.title,
                photo_url=f"/uploads/community/{post.photo_path}",
                caption=post.caption,
                memory_year=post.memory_year,
                created_at=post.created_at,
            )
            for post in rows.scalars().all()
        ]

    async def save_generated_course(self, db: AsyncSession, user: User, course: CourseResponse) -> None:
        """"내가 만든 코스" 영구 저장 — 코스 생성(POST /api/course/generate) 시점에 자동 호출된다."""
        db.add(UserCourse(user_id=user.id, course_id=course.id, course_json=course.model_dump_json()))
        await db.commit()

    async def get_my_courses(self, db: AsyncSession, user: User, *, limit: int = 30, offset: int = 0) -> list[CourseResponse]:
        rows = await db.execute(
            select(UserCourse)
            .where(UserCourse.user_id == user.id)
            .order_by(desc(UserCourse.created_at), desc(UserCourse.id))
            .limit(limit)
            .offset(offset)
        )
        return [CourseResponse.model_validate_json(row.course_json) for row in rows.scalars().all()]

    async def update_nickname(self, db: AsyncSession, user: User, nickname: str) -> User:
        user.nickname = nickname
        await db.commit()
        await db.refresh(user)
        return user

    async def update_photo(self, db: AsyncSession, user: User, file: UploadFile) -> User:
        filename = await save_uploaded_photo(
            file, upload_dir=settings.profile_upload_dir, max_bytes=settings.profile_upload_max_bytes
        )
        user.profile_image_url = f"/uploads/profile/{filename}"
        await db.commit()
        await db.refresh(user)
        return user

    async def delete_account(self, db: AsyncSession, user: User) -> None:
        """회원 탈퇴 — users 행을 지우면 모든 자식 테이블(저장한 골목, 완주 코스,
        게시글·댓글·좋아요·신고·차단·알림·내가 만든 코스)이 DB 레벨 ON DELETE CASCADE로
        함께 삭제된다. 업로드된 사진 파일 자체는 별도 보관 정책 대상이라 여기서 안 지운다."""
        await db.delete(user)
        await db.commit()
