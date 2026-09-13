import datetime

from fastapi import HTTPException, UploadFile
from sqlalchemy import desc, select, func, delete
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.config import settings
from ..db.models import (
    CommunityComment,
    CommunityLike,
    CommunityPost,
    CommunityPostPhoto,
    CommunityReport,
    User,
    UserBlock,
)
from ..models.community import (
    BlockedUserResponse,
    CommentResponse,
    CommunityPostResponse,
    NeighborResponse,
    PostDetailResponse,
)
from .kakao_local import KakaoLocalService
from .notifications import NotificationService
from .photo_upload import save_uploaded_photo

# 이 이상 신고가 쌓이면 관리자 검수 없이 자동으로 숨긴다(관리 화면이 없는 스코프라 경량 모더레이션으로 대신).
_AUTO_HIDE_REPORT_THRESHOLD = 3
_MAX_PHOTOS_PER_POST = 5


class CommunityService:
    """사용자가 직접 올리는 "그 시절 추억" 사진 게시물 — TourAPI처럼 외부에서 실시간으로
    불러오는 게 아니라 우리 DB/디스크가 소스 오브 트루스인 첫 콘텐츠 타입이다."""

    def __init__(
        self,
        kakao_local_service: KakaoLocalService | None = None,
        notification_service: NotificationService | None = None,
    ) -> None:
        self._kakao_local_service = kakao_local_service or KakaoLocalService()
        self._notifications = notification_service or NotificationService()

    async def _blocked_ids(self, db: AsyncSession, user_id: int | None) -> set[int]:
        """user_id가 차단한(=피드에서 숨기고 싶은) 상대 id 집합. 비로그인이면 빈 집합."""
        if user_id is None:
            return set()
        rows = await db.execute(select(UserBlock.blocked_id).where(UserBlock.blocker_id == user_id))
        return {row[0] for row in rows.all()}

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
        board: str,
        files: list[UploadFile] | None = None,
        title: str | None = None,
        location_id: str | None = None,
        caption: str | None = None,
        memory_year: int | None = None,
    ) -> CommunityPostResponse:
        region = region.strip()
        title, caption = (title or '').strip(), (caption or '').strip()
        files = [f for f in (files or []) if f.filename]
        if not 2 <= len(region) <= 100 or len(title) > 120 or len(caption) > 500:
            raise HTTPException(422, '지역·제목·내용의 길이를 확인해주세요')
        if memory_year is not None and not 1900 <= memory_year <= datetime.date.today().year:
            raise HTTPException(422, '사진 연도를 확인해주세요')
        if board == 'memory' and not files:
            raise HTTPException(422, '추억 게시판에는 사진을 첨부해주세요')
        if not title and not caption and not files:
            raise HTTPException(422, '제목이나 내용을 입력해주세요')
        if len(files) > _MAX_PHOTOS_PER_POST:
            raise HTTPException(422, f'사진은 최대 {_MAX_PHOTOS_PER_POST}장까지 첨부할 수 있어요')

        photo_paths = [await self._save_photo(f) for f in files]
        post = CommunityPost(
            user_id=user.id,
            region=region,
            board=board,
            title=title,
            location_id=location_id,
            photo_path=photo_paths[0] if photo_paths else None,
            caption=caption,
            memory_year=memory_year,
        )
        db.add(post)
        await db.flush()
        for position, path in enumerate(photo_paths):
            db.add(CommunityPostPhoto(post_id=post.id, photo_path=path, position=position))
        await db.commit()
        await db.refresh(post)
        photo_urls = [f"/uploads/community/{p}" for p in photo_paths]
        return self._to_response(post, author_nickname=user.nickname, photo_urls=photo_urls)

    async def list_posts(
        self,
        db: AsyncSession,
        *,
        region: str,
        board: str,
        limit: int = 20,
        offset: int = 0,
        query: str = "",
        viewer_id: int | None = None,
    ) -> list[CommunityPostResponse]:
        blocked = await self._blocked_ids(db, viewer_id)
        stmt = (
            select(CommunityPost, User.nickname)
            .join(User, User.id == CommunityPost.user_id)
            .where(CommunityPost.region == region, CommunityPost.board == board, CommunityPost.hidden.is_(False))
            .where(CommunityPost.title.icontains(query, autoescape=True) | CommunityPost.caption.icontains(query, autoescape=True) if query else True)
        )
        if blocked:
            stmt = stmt.where(CommunityPost.user_id.not_in(blocked))
        result = await db.execute(
            stmt.order_by(desc(CommunityPost.created_at), desc(CommunityPost.id)).limit(limit).offset(offset)
        )
        return [self._to_response(post, author_nickname=nickname) for post, nickname in result.all()]

    async def list_posts_by_user(
        self,
        db: AsyncSession,
        *,
        author_id: int,
        region: str,
        limit: int = 20,
        offset: int = 0,
        viewer_id: int | None = None,
    ) -> list[CommunityPostResponse]:
        """"친구찾기"에서 이웃을 눌렀을 때 — 그 사람이 이 동네에 쓴 글(게시판 무관)."""
        blocked = await self._blocked_ids(db, viewer_id)
        if author_id in blocked:
            return []
        author = await db.get(User, author_id)
        if author is None:
            return []
        stmt = (
            select(CommunityPost)
            .where(
                CommunityPost.user_id == author_id,
                CommunityPost.region == region,
                CommunityPost.hidden.is_(False),
            )
            .order_by(desc(CommunityPost.created_at), desc(CommunityPost.id))
            .limit(limit)
            .offset(offset)
        )
        rows = await db.execute(stmt)
        return [self._to_response(post, author_nickname=author.nickname) for post in rows.scalars().all()]

    async def _save_photo(self, file: UploadFile) -> str:
        return await save_uploaded_photo(
            file, upload_dir=settings.community_upload_dir, max_bytes=settings.community_upload_max_bytes
        )

    @staticmethod
    def _to_response(
        post: CommunityPost, *, author_nickname: str, photo_urls: list[str] | None = None
    ) -> CommunityPostResponse:
        cover = f"/uploads/community/{post.photo_path}" if post.photo_path else None
        urls = photo_urls if photo_urls is not None else ([cover] if cover else [])
        return CommunityPostResponse(
            id=post.id,
            author_id=post.user_id,
            author_nickname=author_nickname,
            region=post.region,
            board=post.board,
            title=post.title,
            location_id=post.location_id,
            photo_url=urls[0] if urls else None,
            photo_urls=urls,
            caption=post.caption,
            memory_year=post.memory_year,
            created_at=post.created_at,
        )

    async def _photo_urls(self, db: AsyncSession, post_id: int) -> list[str]:
        rows = await db.execute(
            select(CommunityPostPhoto.photo_path)
            .where(CommunityPostPhoto.post_id == post_id)
            .order_by(CommunityPostPhoto.position)
        )
        return [f"/uploads/community/{path}" for (path,) in rows.all()]


    async def _post(self, db, post_id):
        post = await db.get(CommunityPost, post_id)
        if post is None:
            raise HTTPException(404, '삭제되었거나 없는 글이에요')
        return post

    async def detail(self, db, post_id, user=None):
        post = await self._post(db, post_id)
        blocked = await self._blocked_ids(db, user.id if user else None)
        if post.hidden or post.user_id in blocked:
            raise HTTPException(404, '삭제되었거나 없는 글이에요')
        author = await db.get(User, post.user_id)
        likes = await db.scalar(select(func.count()).select_from(CommunityLike).where(CommunityLike.post_id == post_id))
        comments = await db.scalar(select(func.count()).select_from(CommunityComment).where(CommunityComment.post_id == post_id))
        liked = user is not None and await db.get(CommunityLike, (post_id, user.id)) is not None
        photo_urls = await self._photo_urls(db, post_id)
        response = self._to_response(post, author_nickname=author.nickname, photo_urls=photo_urls)
        return PostDetailResponse(**response.model_dump(), is_mine=user is not None and user.id == post.user_id, liked=liked, like_count=likes, comment_count=comments)

    async def update(self, db, post_id, user, body):
        post = await self._post(db, post_id)
        if post.user_id != user.id:
            raise HTTPException(403, '작성자만 수정할 수 있어요')
        if not body.title.strip() and not body.caption.strip():
            raise HTTPException(422, '제목이나 내용을 입력해주세요')
        post.title, post.caption = body.title.strip(), body.caption.strip()
        await db.commit()
        return await self.detail(db, post_id, user)

    async def remove(self, db, post_id, user):
        post = await self._post(db, post_id)
        if post.user_id != user.id:
            raise HTTPException(403, '작성자만 삭제할 수 있어요')
        # Keep photo bytes until a separate retention cleanup; old browser caches may reference them.
        await db.delete(post)
        await db.commit()

    async def comments(self, db, post_id, user=None, offset=0):
        await self._post(db, post_id)
        blocked = await self._blocked_ids(db, user.id if user else None)
        stmt = (
            select(CommunityComment, User.nickname)
            .join(User, User.id == CommunityComment.user_id)
            .where(CommunityComment.post_id == post_id, CommunityComment.hidden.is_(False))
        )
        if blocked:
            stmt = stmt.where(CommunityComment.user_id.not_in(blocked))
        rows = await db.execute(stmt.order_by(CommunityComment.id).offset(offset).limit(30))
        return [CommentResponse(id=c.id, author_id=c.user_id, author_nickname=n, body=c.body, parent_id=c.parent_id, created_at=c.created_at, is_mine=user is not None and c.user_id == user.id) for c,n in rows]

    async def add_comment(self, db, post_id, user, body, parent_id=None):
        post = await self._post(db, post_id)
        parent: CommunityComment | None = None
        if parent_id is not None:
            parent = await db.get(CommunityComment, parent_id)
            if parent is None or parent.post_id != post_id:
                raise HTTPException(404, '답글을 달 댓글을 찾지 못했어요')
            # 답글의 답글은 만들지 않고, 그 댓글의 최상위 부모에 묶어서 1단계 스레드만 유지한다.
            if parent.parent_id is not None:
                parent = await db.get(CommunityComment, parent.parent_id)

        comment = CommunityComment(
            post_id=post_id, user_id=user.id, body=body, parent_id=parent.id if parent else None
        )
        db.add(comment)
        await db.commit()
        await db.refresh(comment)
        await self._notifications.notify_comment(db, post=post, actor=user, comment_id=comment.id)
        if parent is not None:
            reply_author = await db.get(User, parent.user_id)
            if reply_author is not None:
                await self._notifications.notify_reply(
                    db, post=post, actor=user, comment_id=comment.id, reply_to=reply_author
                )
        return CommentResponse(
            id=comment.id, author_id=user.id, author_nickname=user.nickname, body=comment.body,
            parent_id=comment.parent_id, created_at=comment.created_at, is_mine=True,
        )

    async def remove_comment(self, db, post_id, comment_id, user):
        comment = await db.get(CommunityComment, comment_id)
        if comment is None or comment.post_id != post_id:
            raise HTTPException(404, '댓글을 찾지 못했어요')
        if comment.user_id != user.id:
            raise HTTPException(403, '작성자만 삭제할 수 있어요')
        await db.delete(comment)
        await db.commit()

    async def like(self, db, post_id, user, liked):
        post = await self._post(db, post_id)
        if liked:
            await db.execute(insert(CommunityLike).values(post_id=post_id, user_id=user.id).on_conflict_do_nothing())
        else:
            await db.execute(delete(CommunityLike).where(CommunityLike.post_id == post_id, CommunityLike.user_id == user.id))
        await db.commit()
        if liked:
            await self._notifications.notify_like(db, post=post, actor=user)
        return await self.detail(db, post_id, user)

    # -- 신고/차단 -----------------------------------------------------------

    async def report(self, db: AsyncSession, user: User, *, target_type: str, target_id: int, reason: str) -> None:
        if target_type == "post":
            target = await db.get(CommunityPost, target_id)
        elif target_type == "comment":
            target = await db.get(CommunityComment, target_id)
        else:
            raise HTTPException(400, "잘못된 신고 대상이에요")
        if target is None:
            raise HTTPException(404, "신고할 대상을 찾지 못했어요")
        if target.user_id == user.id:
            raise HTTPException(400, "본인 글/댓글은 신고할 수 없어요")

        result = await db.execute(
            insert(CommunityReport)
            .values(reporter_id=user.id, target_type=target_type, target_id=target_id, reason=reason)
            .on_conflict_do_nothing()
            .returning(CommunityReport.id)
        )
        await db.commit()
        if result.first() is None:
            return  # 이미 신고한 대상 — 중복 집계하지 않는다.

        count = await db.scalar(
            select(func.count())
            .select_from(CommunityReport)
            .where(CommunityReport.target_type == target_type, CommunityReport.target_id == target_id)
        )
        if count >= _AUTO_HIDE_REPORT_THRESHOLD:
            target.hidden = True
            await db.commit()

    async def block(self, db: AsyncSession, user: User, blocked_user_id: int) -> None:
        if blocked_user_id == user.id:
            raise HTTPException(400, "본인은 차단할 수 없어요")
        target = await db.get(User, blocked_user_id)
        if target is None:
            raise HTTPException(404, "사용자를 찾지 못했어요")
        await db.execute(
            insert(UserBlock).values(blocker_id=user.id, blocked_id=blocked_user_id).on_conflict_do_nothing()
        )
        await db.commit()

    async def unblock(self, db: AsyncSession, user: User, blocked_user_id: int) -> None:
        await db.execute(
            delete(UserBlock).where(UserBlock.blocker_id == user.id, UserBlock.blocked_id == blocked_user_id)
        )
        await db.commit()

    async def list_blocked(self, db: AsyncSession, user: User) -> list[BlockedUserResponse]:
        rows = await db.execute(
            select(User.id, User.nickname)
            .join(UserBlock, UserBlock.blocked_id == User.id)
            .where(UserBlock.blocker_id == user.id)
            .order_by(UserBlock.created_at.desc())
        )
        return [BlockedUserResponse(user_id=row.id, nickname=row.nickname) for row in rows.all()]

    # -- 동네 이웃(친구찾기) ---------------------------------------------------

    async def neighbors(self, db: AsyncSession, user: User, *, region: str) -> list[NeighborResponse]:
        """같은 "내 동네"로 설정한 다른 사용자들을, 그 동네 게시글 수가 많은 순으로 보여준다.
        카카오톡 친구 API는 별도 심사가 필요한 제한 API라 쓰지 않고, 순수 커뮤니티
        데이터(같은 home_region)만으로 "동네 이웃"을 구성한다."""
        blocked = await self._blocked_ids(db, user.id)
        post_counts = (
            select(CommunityPost.user_id, func.count().label("post_count"))
            .where(CommunityPost.region == region, CommunityPost.hidden.is_(False))
            .group_by(CommunityPost.user_id)
            .subquery()
        )
        stmt = (
            select(User.id, User.nickname, User.profile_image_url, func.coalesce(post_counts.c.post_count, 0))
            .outerjoin(post_counts, post_counts.c.user_id == User.id)
            .where(User.home_region == region, User.id != user.id)
        )
        if blocked:
            stmt = stmt.where(User.id.not_in(blocked))
        rows = await db.execute(stmt.order_by(desc(func.coalesce(post_counts.c.post_count, 0)), User.nickname))
        return [
            NeighborResponse(user_id=row[0], nickname=row[1], profile_image_url=row[2], post_count=row[3])
            for row in rows.all()
        ]
