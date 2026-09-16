import html
import json

from fastapi import HTTPException, UploadFile
from sqlalchemy import delete, desc, func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..db.models import CustomCourse, CustomCourseComment, CustomCourseVote, User
from ..models.custom_course import (
    CustomCourseCommentResponse,
    CustomCourseCreateRequest,
    CustomCoursePlaceResponse,
    CustomCourseResponse,
    CustomCourseSummaryResponse,
    CustomCourseUpdateRequest,
)
from .map_html import render_map_page, render_message_page
from .photo_upload import save_uploaded_photo

_MAX_COMMENT_LENGTH = 300


class CustomCourseService:
    """사용자가 직접 만들어 커뮤니티에 공유하는 "코스 커스텀" — 우리 DB가
    소스 오브 트루스인 콘텐츠 타입이라 community.py의 게시글/좋아요/댓글
    패턴을 그대로 따른다(투표만 좋아요와 달리 -1/1 두 방향)."""

    async def _course(self, db: AsyncSession, course_id: int) -> CustomCourse:
        course = await db.get(CustomCourse, course_id)
        if course is None:
            raise HTTPException(404, "삭제되었거나 없는 코스예요")
        return course

    async def _vote_counts(self, db: AsyncSession, course_id: int) -> tuple[int, int]:
        rows = await db.execute(
            select(CustomCourseVote.value, func.count())
            .where(CustomCourseVote.course_id == course_id)
            .group_by(CustomCourseVote.value)
        )
        counts = dict(rows.all())
        return counts.get(1, 0), counts.get(-1, 0)

    async def _comment_count(self, db: AsyncSession, course_id: int) -> int:
        return await db.scalar(
            select(func.count()).select_from(CustomCourseComment).where(CustomCourseComment.course_id == course_id)
        )

    def _to_response(self, course: CustomCourse, *, author_nickname: str) -> CustomCourseResponse:
        places = [CustomCoursePlaceResponse.model_validate(p) for p in json.loads(course.places_json)]
        return CustomCourseResponse(
            id=course.id,
            author_id=course.user_id,
            author_nickname=author_nickname,
            title=course.title,
            category=course.category,
            description=course.description,
            places=places,
            is_public=course.is_public,
            created_at=course.created_at,
        )

    async def create(self, db: AsyncSession, user: User, body: CustomCourseCreateRequest) -> CustomCourseResponse:
        course = CustomCourse(
            user_id=user.id,
            title=body.title,
            category=body.category,
            description=body.description,
            places_json=json.dumps([p.model_dump() for p in body.places]),
            is_public=body.is_public,
        )
        db.add(course)
        await db.commit()
        return await self.detail(db, course.id, user)

    async def update(
        self, db: AsyncSession, course_id: int, user: User, body: CustomCourseUpdateRequest
    ) -> CustomCourseResponse:
        course = await self._course(db, course_id)
        if course.user_id != user.id:
            raise HTTPException(403, "작성자만 수정할 수 있어요")
        course.title = body.title
        course.category = body.category
        course.description = body.description
        course.places_json = json.dumps([p.model_dump() for p in body.places])
        course.is_public = body.is_public
        await db.commit()
        return await self.detail(db, course_id, user)

    async def list_courses(
        self,
        db: AsyncSession,
        *,
        category: str | None = None,
        sort: str = "recent",
        limit: int = 20,
        offset: int = 0,
        author_id: int | None = None,
    ) -> list[CustomCourseSummaryResponse]:
        stmt = select(CustomCourse).order_by(desc(CustomCourse.created_at)).offset(offset).limit(limit)
        if category:
            stmt = stmt.where(CustomCourse.category == category)
        if author_id is not None:
            # "내 코스" 목록은 비공개로 만든 것도 본인에겐 보여야 한다.
            stmt = stmt.where(CustomCourse.user_id == author_id)
        else:
            stmt = stmt.where(CustomCourse.is_public.is_(True))
        courses = (await db.execute(stmt)).scalars().all()

        summaries: list[CustomCourseSummaryResponse] = []
        for course in courses:
            author = await db.get(User, course.user_id)
            likes, dislikes = await self._vote_counts(db, course.id)
            places = json.loads(course.places_json)
            summaries.append(
                CustomCourseSummaryResponse(
                    id=course.id,
                    author_id=course.user_id,
                    author_nickname=author.nickname if author else "탈퇴한 사용자",
                    title=course.title,
                    category=course.category,
                    place_count=len(places),
                    thumbnail_url=next((p.get("image_url") for p in places if p.get("image_url")), None),
                    score=likes - dislikes,
                    like_count=likes,
                    dislike_count=dislikes,
                    comment_count=await self._comment_count(db, course.id),
                    created_at=course.created_at,
                )
            )
        if sort == "popular":
            summaries.sort(key=lambda s: s.score, reverse=True)
        return summaries

    async def list_public_by_author(
        self, db: AsyncSession, author_id: int, *, limit: int = 10
    ) -> list[CustomCourseSummaryResponse]:
        """연결된 친구의 "추억 프로필"에서 공개 코스만 보여줄 때 쓴다 — list_courses의
        author_id 필터는 "내 코스"(비공개 포함) 전용이라 여기서 재사용하지 않는다."""
        stmt = (
            select(CustomCourse)
            .where(CustomCourse.user_id == author_id, CustomCourse.is_public.is_(True))
            .order_by(desc(CustomCourse.created_at))
            .limit(limit)
        )
        courses = (await db.execute(stmt)).scalars().all()
        author = await db.get(User, author_id)
        summaries: list[CustomCourseSummaryResponse] = []
        for course in courses:
            likes, dislikes = await self._vote_counts(db, course.id)
            places = json.loads(course.places_json)
            summaries.append(
                CustomCourseSummaryResponse(
                    id=course.id,
                    author_id=author_id,
                    author_nickname=author.nickname if author else "탈퇴한 사용자",
                    title=course.title,
                    category=course.category,
                    place_count=len(places),
                    thumbnail_url=next((p.get("image_url") for p in places if p.get("image_url")), None),
                    score=likes - dislikes,
                    like_count=likes,
                    dislike_count=dislikes,
                    comment_count=await self._comment_count(db, course.id),
                    created_at=course.created_at,
                )
            )
        return summaries

    async def detail(self, db: AsyncSession, course_id: int, user: User | None = None) -> CustomCourseResponse:
        course = await self._course(db, course_id)
        if not course.is_public and (user is None or user.id != course.user_id):
            raise HTTPException(404, "삭제되었거나 없는 코스예요")
        author = await db.get(User, course.user_id)
        likes, dislikes = await self._vote_counts(db, course_id)
        my_vote = 0
        if user is not None:
            vote = await db.scalar(
                select(CustomCourseVote.value).where(
                    CustomCourseVote.course_id == course_id, CustomCourseVote.user_id == user.id
                )
            )
            my_vote = vote or 0
        response = self._to_response(course, author_nickname=author.nickname if author else "탈퇴한 사용자")
        return response.model_copy(
            update={
                "like_count": likes,
                "dislike_count": dislikes,
                "comment_count": await self._comment_count(db, course_id),
                "is_mine": user is not None and user.id == course.user_id,
                "my_vote": my_vote,
            }
        )

    async def remove(self, db: AsyncSession, course_id: int, user: User) -> None:
        course = await self._course(db, course_id)
        if course.user_id != user.id:
            raise HTTPException(403, "작성자만 삭제할 수 있어요")
        await db.delete(course)
        await db.commit()

    async def vote(self, db: AsyncSession, course_id: int, user: User, value: int) -> CustomCourseResponse:
        await self._course(db, course_id)  # 404 확인
        if value == 0:
            await db.execute(
                delete(CustomCourseVote).where(
                    CustomCourseVote.course_id == course_id, CustomCourseVote.user_id == user.id
                )
            )
        else:
            stmt = insert(CustomCourseVote).values(course_id=course_id, user_id=user.id, value=value)
            stmt = stmt.on_conflict_do_update(
                index_elements=[CustomCourseVote.course_id, CustomCourseVote.user_id],
                set_={"value": value},
            )
            await db.execute(stmt)
        await db.commit()
        return await self.detail(db, course_id, user)

    async def comments(self, db: AsyncSession, course_id: int, user: User | None = None) -> list[CustomCourseCommentResponse]:
        await self._course(db, course_id)  # 404 확인
        rows = await db.execute(
            select(CustomCourseComment)
            .where(CustomCourseComment.course_id == course_id)
            .order_by(CustomCourseComment.created_at)
        )
        comments = rows.scalars().all()
        result = []
        for comment in comments:
            author = await db.get(User, comment.user_id)
            result.append(
                CustomCourseCommentResponse(
                    id=comment.id,
                    author_id=comment.user_id,
                    author_nickname=author.nickname if author else "탈퇴한 사용자",
                    body=comment.body,
                    is_mine=user is not None and user.id == comment.user_id,
                    created_at=comment.created_at,
                )
            )
        return result

    async def add_comment(self, db: AsyncSession, course_id: int, user: User, body: str) -> CustomCourseCommentResponse:
        await self._course(db, course_id)  # 404 확인
        comment = CustomCourseComment(course_id=course_id, user_id=user.id, body=body[:_MAX_COMMENT_LENGTH])
        db.add(comment)
        await db.commit()
        return CustomCourseCommentResponse(
            id=comment.id,
            author_id=user.id,
            author_nickname=user.nickname,
            body=comment.body,
            is_mine=True,
            created_at=comment.created_at,
        )

    async def remove_comment(self, db: AsyncSession, course_id: int, comment_id: int, user: User) -> None:
        comment = await db.get(CustomCourseComment, comment_id)
        if comment is None or comment.course_id != course_id:
            raise HTTPException(404, "삭제되었거나 없는 댓글이에요")
        if comment.user_id != user.id:
            raise HTTPException(403, "작성자만 삭제할 수 있어요")
        await db.delete(comment)
        await db.commit()

    async def upload_photo(self, file: UploadFile) -> str:
        """코스 장소에 직접 등록하는 사진 — 검색 결과 썸네일을 대체한다."""
        return await save_uploaded_photo(
            file,
            upload_dir=settings.custom_course_upload_dir,
            max_bytes=settings.custom_course_upload_max_bytes,
            public_path_prefix="custom-course",
        )

    async def require_course(self, db: AsyncSession, course_id: int) -> CustomCourse:
        """다른 서비스(추억 매칭 등)가 코스 원본 row가 필요할 때 쓰는 공개 진입점."""
        return await self._course(db, course_id)

    async def render_map(self, db: AsyncSession, course_id: int) -> str:
        """코스 상세 "지도로 보기" — 담긴 장소들을 좌표 순서대로 번호 마커로
        보여주는 웹뷰 페이지(community_map.py와 같은 패턴)."""
        course = await self._course(db, course_id)
        if not settings.kakao_map_js_key:
            return render_message_page("카카오맵 키가 설정되지 않았어요")

        places = json.loads(course.places_json)
        markers = [
            {
                "lat": p["latitude"],
                "lng": p["longitude"],
                "title": html.escape(p["name"]),
                "place": html.escape(p.get("address") or ""),
                "linkUrl": None,
            }
            for p in places
            if p.get("latitude") is not None and p.get("longitude") is not None
        ]
        if not markers:
            return render_message_page("좌표가 있는 장소가 없어요")
        return render_map_page(markers=markers, js_key=settings.kakao_map_js_key)
