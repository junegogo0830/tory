import datetime

from fastapi import HTTPException, UploadFile
from sqlalchemy import desc, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..db.models import CommunityPost, CompletedCourse, CustomCourse, SavedCourse, SavedLocation, User, UserCourse
from ..models.course import CourseResponse
from ..models.profile import (
    MyMemoryResponse,
    ProfileInfoUpdateRequest,
    ProfileResponse,
    RecentCourseResponse,
    SavedCourseResponse,
    SavedLocationSummary,
)
from .custom_course import CustomCourseService
from .photo_upload import save_uploaded_photo
from .recommendation import RecommendationService
from .tourapi import TourApiService


class ProfileService:
    def __init__(
        self,
        tour_api_service: TourApiService | None = None,
        recommendation_service: RecommendationService | None = None,
        custom_course_service: CustomCourseService | None = None,
    ) -> None:
        self._tour_api_service = tour_api_service or TourApiService()
        self._recommendation_service = recommendation_service or RecommendationService()
        self._custom_course_service = custom_course_service or CustomCourseService()

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

        registered_course_count = await db.scalar(
            select(func.count()).select_from(CustomCourse).where(CustomCourse.user_id == user.id)
        )
        saved_course_count = await db.scalar(
            select(func.count()).select_from(SavedCourse).where(SavedCourse.user_id == user.id)
        )
        post_count = await db.scalar(
            select(func.count()).select_from(CommunityPost).where(CommunityPost.user_id == user.id)
        )

        return ProfileResponse(
            user_id=user.id,
            display_name=user.nickname,
            tagline="나의 추억 여행을 기록하고 있어요",
            profile_image_url=user.profile_image_url,
            registered_course_count=registered_course_count or 0,
            saved_course_count=saved_course_count or 0,
            post_count=post_count or 0,
            saved_locations=saved_locations,
            home_region=user.home_region,
            age_group=user.age_group,
            gender=user.gender,
            full_name=user.full_name,
            phone_number=user.phone_number,
            onboarding_completed=user.onboarded_at is not None,
            has_password=user.password_hash is not None,
            friend_finder_enabled=user.friend_finder_enabled,
        )

    async def update_info(self, db: AsyncSession, user: User, body: ProfileInfoUpdateRequest) -> User:
        if body.gender is not None:
            user.gender = body.gender
        if body.full_name is not None:
            user.full_name = body.full_name.strip() or None
        if body.phone_number is not None:
            phone = body.phone_number.strip() or None
            if phone is not None:
                existing = await db.scalar(
                    select(User.id).where(User.phone_number == phone, User.id != user.id)
                )
                if existing is not None:
                    raise HTTPException(422, '이미 다른 계정에서 쓰고 있는 번호예요')
            user.phone_number = phone
        if body.friend_finder_enabled is not None:
            user.friend_finder_enabled = body.friend_finder_enabled
        await db.commit()
        await db.refresh(user)
        return user

    async def complete_onboarding(self, db: AsyncSession, user: User, age_group: str | None) -> User:
        """첫 로그인 온보딩 — 완료든 건너뛰기든 호출하면 다시 안 뜨게 된다."""
        if age_group is not None:
            user.age_group = age_group
        user.onboarded_at = datetime.datetime.now(datetime.timezone.utc)
        await db.commit()
        await db.refresh(user)
        return user

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

    async def save_course(
        self, db: AsyncSession, user: User, course_type: str, course_id: str, course: CourseResponse | None = None
    ) -> None:
        """코스 북마크. generated는 지금 이 순간의 코스를 스냅샷해둔다(캐시가 나중에
        만료돼도 저장한 내용은 그대로 보이게) — custom은 우리 DB가 소스 오브
        트루스라 존재 확인만 하고 매번 그때그때 조회한다.

        [course]가 오면(화면이 식사 추가처럼 서버 캐시엔 없는 변경을 들고 있을
        때) id로 다시 조회하지 않고 그 스냅샷을 그대로 믿는다 — 안 그러면
        방금 추가한 식당이 저장 시점에 사라진다."""
        course_json: str | None = None
        if course_type == "generated":
            if course is not None:
                course_json = course.model_dump_json()
            else:
                fetched = await self._recommendation_service.get_course_by_id(course_id)
                if fetched is None:
                    raise HTTPException(404, "존재하지 않는 코스예요")
                course_json = fetched.model_dump_json()
        elif course_type == "custom":
            await self._custom_course_service.require_course(db, int(course_id))
        else:
            raise HTTPException(422, "올바르지 않은 코스 종류예요")

        stmt = insert(SavedCourse).values(
            user_id=user.id, course_type=course_type, course_id=course_id, course_json=course_json
        )
        stmt = stmt.on_conflict_do_nothing(index_elements=[SavedCourse.user_id, SavedCourse.course_type, SavedCourse.course_id])
        await db.execute(stmt)
        await db.commit()

    async def unsave_course(self, db: AsyncSession, user: User, course_type: str, course_id: str) -> None:
        row = await db.scalar(
            select(SavedCourse).where(
                SavedCourse.user_id == user.id, SavedCourse.course_type == course_type, SavedCourse.course_id == course_id
            )
        )
        if row is not None:
            await db.delete(row)
            await db.commit()

    async def is_course_saved(self, db: AsyncSession, user: User, course_type: str, course_id: str) -> bool:
        row = await db.scalar(
            select(SavedCourse.id).where(
                SavedCourse.user_id == user.id, SavedCourse.course_type == course_type, SavedCourse.course_id == course_id
            )
        )
        return row is not None

    async def _custom_course_fields(self, db: AsyncSession, course_id: str) -> tuple[str, str | None, str | None, int] | None:
        try:
            course = await self._custom_course_service.detail(db, int(course_id))
        except HTTPException:
            return None  # 삭제된 커스텀 코스는 조용히 뺀다.
        thumbnail = next((p.image_url for p in course.places if p.image_url), None)
        return course.title, course.category, thumbnail, len(course.places)

    async def list_saved_courses(self, db: AsyncSession, user: User) -> list[SavedCourseResponse]:
        rows = await db.execute(
            select(SavedCourse).where(SavedCourse.user_id == user.id).order_by(desc(SavedCourse.created_at))
        )
        results: list[SavedCourseResponse] = []
        for saved in rows.scalars().all():
            if saved.course_type == "generated":
                if saved.course_json is None:
                    continue
                course = CourseResponse.model_validate_json(saved.course_json)
                fields = (course.title, course.category, course.image_url, len(course.stops))
            else:
                fields = await self._custom_course_fields(db, saved.course_id)
                if fields is None:
                    continue
            title, category, thumbnail_url, place_count = fields
            results.append(
                SavedCourseResponse(
                    course_type=saved.course_type,
                    course_id=saved.course_id,
                    title=title,
                    category=category,
                    thumbnail_url=thumbnail_url,
                    place_count=place_count,
                    saved_at=saved.created_at,
                )
            )
        return results

    async def record_course_view(self, db: AsyncSession, user: User, course_type: str, course_id: str) -> None:
        """홈 "이어보기"용 — 코스 상세 화면을 열 때마다 마지막으로 본 코스를 덮어쓴다."""
        if course_type not in ("generated", "custom"):
            raise HTTPException(422, "올바르지 않은 코스 종류예요")
        user.last_viewed_course_type = course_type
        user.last_viewed_course_id = course_id
        user.last_viewed_course_at = datetime.datetime.now(datetime.timezone.utc)
        await db.commit()

    async def get_recent_course(self, db: AsyncSession, user: User) -> RecentCourseResponse | None:
        if user.last_viewed_course_type is None or user.last_viewed_course_id is None:
            return None

        if user.last_viewed_course_type == "generated":
            course = await self._recommendation_service.get_course_by_id(user.last_viewed_course_id)
            fields = (course.title, course.category, course.image_url, len(course.stops)) if course else None
        else:
            fields = await self._custom_course_fields(db, user.last_viewed_course_id)

        if fields is None:
            return None  # 캐시 만료(생성 코스) 또는 삭제된 커스텀 코스 — 조용히 숨긴다.

        title, category, thumbnail_url, place_count = fields
        return RecentCourseResponse(
            course_type=user.last_viewed_course_type,
            course_id=user.last_viewed_course_id,
            title=title,
            category=category,
            thumbnail_url=thumbnail_url,
            place_count=place_count,
            viewed_at=user.last_viewed_course_at,
        )

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
        user.profile_image_url = await save_uploaded_photo(
            file,
            upload_dir=settings.profile_upload_dir,
            max_bytes=settings.profile_upload_max_bytes,
            public_path_prefix="profile",
        )
        await db.commit()
        await db.refresh(user)
        return user

    async def delete_account(self, db: AsyncSession, user: User) -> None:
        """회원 탈퇴 — users 행을 지우면 모든 자식 테이블(저장한 골목, 완주 코스,
        게시글·댓글·좋아요·신고·차단·알림·내가 만든 코스)이 DB 레벨 ON DELETE CASCADE로
        함께 삭제된다. 업로드된 사진 파일 자체는 별도 보관 정책 대상이라 여기서 안 지운다."""
        await db.delete(user)
        await db.commit()
