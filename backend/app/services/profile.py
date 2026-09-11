from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db.models import CommunityPost, CompletedCourse, SavedLocation, User
from ..models.profile import ProfileResponse, SavedLocationSummary
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
