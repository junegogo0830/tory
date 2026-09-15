import datetime
import json

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
    RegionMembership,
    User,
    UserBlock,
)
from ..models.community import (
    MAX_BLOCK_TEXT_LENGTH,
    MAX_CONTENT_BLOCKS,
    TRADE_STATUSES,
    BlockedUserResponse,
    CommentResponse,
    CommunityPostResponse,
    ContentBlockResponse,
    NeighborResponse,
    PostDetailResponse,
    RegionStatsResponse,
    SchoolSearchResult,
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
        """"보고 있는" 동네를 바꾼다. 처음 가입하는 지역이면 가입 이력
        (region_memberships)에도 함께 남는다 — 이미 가입한 지역으로 전환하는
        건 이 호출 하나로 끝나지만(가입 화면 없이 바로), 새 지역 "가입"은
        프론트가 가입 확인 화면을 먼저 보여준 뒤에 이 메서드를 호출한다."""
        user.home_region = region
        await db.execute(
            insert(RegionMembership)
            .values(user_id=user.id, region=region)
            .on_conflict_do_nothing(index_elements=["user_id", "region"])
        )
        await db.commit()

    async def list_my_regions(self, db: AsyncSession, user: User) -> list[str]:
        """이 사용자가 가입한 모든 동네 — 최근 가입한 순. 커뮤니티 탭의 지역
        토글이 그대로 보여준다."""
        rows = await db.execute(
            select(RegionMembership.region)
            .where(RegionMembership.user_id == user.id)
            .order_by(desc(RegionMembership.joined_at))
        )
        return [row[0] for row in rows.all()]

    async def region_stats(self, db: AsyncSession, region: str) -> RegionStatsResponse:
        member_count = await db.scalar(
            select(func.count()).select_from(RegionMembership).where(RegionMembership.region == region)
        )
        post_count = await db.scalar(
            select(func.count())
            .select_from(CommunityPost)
            .where(CommunityPost.region == region, CommunityPost.hidden.is_(False))
        )
        return RegionStatsResponse(region=region, member_count=member_count or 0, post_count=post_count or 0)

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
        reveal_at: datetime.datetime | None = None,
        price: int | None = None,
        trade_status: str | None = None,
        is_trade: bool = True,
        content_blocks: str | None = None,
    ) -> CommunityPostResponse:
        region = region.strip()
        title, caption = (title or '').strip(), (caption or '').strip()
        files = [f for f in (files or []) if f.filename]

        # 블로그 스타일 글쓰기 — 텍스트/사진 블록이 오면 검증하고, caption을 명시
        # 안 했으면 블록의 텍스트를 이어붙여 파생시킨다(목록 카드/검색이 지금처럼
        # 동작하려면 caption이 그대로 채워져 있어야 한다).
        parsed_blocks = self._parse_content_blocks(content_blocks, photo_count=len(files))
        if parsed_blocks is not None and not caption:
            caption = '\n\n'.join(b['text'] for b in parsed_blocks if b['type'] == 'text' and b['text']).strip()

        if not 2 <= len(region) <= 100 or len(title) > 120 or len(caption) > 2000:
            raise HTTPException(422, '지역·제목·내용의 길이를 확인해주세요')
        if memory_year is not None and not 1900 <= memory_year <= datetime.date.today().year:
            raise HTTPException(422, '사진 연도를 확인해주세요')
        if board == 'memory' and not files:
            raise HTTPException(422, '추억 게시판에는 사진을 첨부해주세요')
        if not title and not caption and not files:
            raise HTTPException(422, '제목이나 내용을 입력해주세요')
        if len(files) > _MAX_PHOTOS_PER_POST:
            raise HTTPException(422, f'사진은 최대 {_MAX_PHOTOS_PER_POST}장까지 첨부할 수 있어요')

        # 주민 게시판은 글쓰기 시 "중고거래" 또는 "자유글" 카테고리를 고른다.
        # 중고거래를 골랐을 때만 가격/거래상태를 갖고, 상태를 안 골랐으면
        # "판매중"이 기본이다. 자유글이거나 다른 게시판이면 두 값 다 항상
        # None으로 무시한다(잘못 섞여 들어오는 걸 막는다).
        if board == 'resident' and is_trade:
            if price is not None and price < 0:
                raise HTTPException(422, '가격을 확인해주세요')
            trade_status = trade_status if trade_status in TRADE_STATUSES else '판매중'
        else:
            price, trade_status = None, None

        if board == 'timecapsule':
            if reveal_at is not None and reveal_at.tzinfo is None:
                # 프론트가 타임존 없는 문자열을 보내는 경우를 대비한 방어적 처리 — UTC로 간주한다.
                reveal_at = reveal_at.replace(tzinfo=datetime.timezone.utc)
            now = datetime.datetime.now(datetime.timezone.utc)
            if reveal_at is None or reveal_at <= now:
                raise HTTPException(422, '봉인을 풀 미래 날짜를 선택해주세요')
            if reveal_at > now + datetime.timedelta(days=365 * 10):
                raise HTTPException(422, '봉인 기간은 최대 10년까지예요')
        else:
            reveal_at = None

        photo_paths = [await self._save_photo(f) for f in files]
        post = CommunityPost(
            user_id=user.id,
            region=region,
            board=board,
            title=title,
            location_id=location_id,
            photo_path=photo_paths[0] if photo_paths else None,
            caption=caption,
            content_blocks=json.dumps(parsed_blocks) if parsed_blocks is not None else None,
            memory_year=memory_year,
            reveal_at=reveal_at,
            price=price,
            trade_status=trade_status,
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
        region: str | None = None,
        limit: int = 20,
        offset: int = 0,
        viewer_id: int | None = None,
    ) -> list[CommunityPostResponse]:
        """"친구찾기"에서 이웃을 눌렀을 때 — 그 사람이 이 동네에 쓴 글(게시판 무관).
        region이 None이면 지역 무관 전체 글(프로필 "등록한 게시글")을 준다."""
        blocked = await self._blocked_ids(db, viewer_id)
        if author_id in blocked:
            return []
        author = await db.get(User, author_id)
        if author is None:
            return []
        conditions = [CommunityPost.user_id == author_id, CommunityPost.hidden.is_(False)]
        if region is not None:
            conditions.append(CommunityPost.region == region)
        stmt = (
            select(CommunityPost)
            .where(*conditions)
            .order_by(desc(CommunityPost.created_at), desc(CommunityPost.id))
            .limit(limit)
            .offset(offset)
        )
        rows = await db.execute(stmt)
        return [self._to_response(post, author_nickname=author.nickname) for post in rows.scalars().all()]

    @staticmethod
    def _parse_content_blocks(raw: str | None, *, photo_count: int) -> list[dict] | None:
        """블로그 스타일 글쓰기 본문 블록 JSON을 검증한다.

        text 블록은 `{"type": "text", "text": "..."}`, image 블록은 그 글과 함께
        업로드된 파일 순서를 가리키는 `{"type": "image", "index": N}` — URL은
        저장하지 않고 응답을 만들 때(`_resolve_content_blocks`) 그때그때 채운다.
        """
        if raw is None or not raw.strip():
            return None
        try:
            blocks = json.loads(raw)
        except ValueError:
            raise HTTPException(422, '본문 형식이 올바르지 않아요') from None
        if not isinstance(blocks, list) or not blocks:
            raise HTTPException(422, '본문 형식이 올바르지 않아요')
        if len(blocks) > MAX_CONTENT_BLOCKS:
            raise HTTPException(422, f'본문은 최대 {MAX_CONTENT_BLOCKS}블록까지 작성할 수 있어요')

        parsed: list[dict] = []
        for block in blocks:
            if not isinstance(block, dict):
                raise HTTPException(422, '본문 형식이 올바르지 않아요')
            block_type = block.get('type')
            if block_type == 'text':
                text = str(block.get('text') or '').strip()
                if len(text) > MAX_BLOCK_TEXT_LENGTH:
                    raise HTTPException(422, '블록 하나의 글자 수를 확인해주세요')
                if text:
                    parsed.append({'type': 'text', 'text': text})
            elif block_type == 'image':
                index = block.get('index')
                if not isinstance(index, int) or not 0 <= index < photo_count:
                    raise HTTPException(422, '본문에 첨부한 사진을 확인해주세요')
                parsed.append({'type': 'image', 'index': index})
            else:
                raise HTTPException(422, '본문 형식이 올바르지 않아요')
        return parsed or None

    @staticmethod
    def _resolve_content_blocks(post: CommunityPost, photo_urls: list[str]) -> list[ContentBlockResponse] | None:
        if not post.content_blocks:
            return None
        raw_blocks = json.loads(post.content_blocks)
        resolved: list[ContentBlockResponse] = []
        for block in raw_blocks:
            if block['type'] == 'image':
                index = block['index']
                if 0 <= index < len(photo_urls):
                    resolved.append(ContentBlockResponse(type='image', image_url=photo_urls[index]))
            else:
                resolved.append(ContentBlockResponse(type='text', text=block.get('text')))
        return resolved or None

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
        # 타임캡슐은 reveal_at이 지나기 전까지 내용을 가린다 — 제목/내용/사진을
        # 아예 빼서 클라이언트가 실수로라도 못 읽게 한다("잠긴 카드처럼 보이게만"
        # 프론트에서 처리하는 게 아니라 서버가 애초에 안 준다).
        revealed = post.board != "timecapsule" or post.reveal_at is None or post.reveal_at <= datetime.datetime.now(datetime.timezone.utc)
        # content_blocks의 image 블록은 전체 사진 순서를 알아야 URL을 맞게 채울 수
        # 있다 — photo_urls를 명시적으로 받은 호출(글쓰기 직후/상세 조회)에서만
        # 채우고, 커버 사진 하나만 아는 목록 조회에서는 굳이 만들지 않는다(목록
        # 카드는 어차피 caption/photo_url만 쓴다).
        content_blocks = (
            CommunityService._resolve_content_blocks(post, urls) if revealed and photo_urls is not None else None
        )
        return CommunityPostResponse(
            id=post.id,
            author_id=post.user_id,
            author_nickname=author_nickname,
            region=post.region,
            board=post.board,
            title=post.title if revealed else None,
            location_id=post.location_id,
            photo_url=urls[0] if urls and revealed else None,
            photo_urls=urls if revealed else [],
            caption=post.caption if revealed else None,
            content_blocks=content_blocks,
            memory_year=post.memory_year if revealed else None,
            reveal_at=post.reveal_at,
            revealed=revealed,
            price=post.price if revealed else None,
            trade_status=post.trade_status if revealed else None,
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
        # 이 수정 화면은 블록 단위 편집을 지원하지 않는다 — 블록 글을 여기서
        # 고치면 caption만 바뀌고 화면은 여전히 옛 블록을 그리는 모순이 생기니,
        # 수정 시점에 content_blocks를 지워 캡션 기반(평면) 렌더링으로 되돌린다.
        post.content_blocks = None
        await db.commit()
        return await self.detail(db, post_id, user)

    async def update_trade_status(self, db, post_id, user, trade_status: str):
        post = await self._post(db, post_id)
        if post.user_id != user.id:
            raise HTTPException(403, '작성자만 변경할 수 있어요')
        if post.board != 'resident':
            raise HTTPException(422, '주민 게시판 글에만 거래 상태가 있어요')
        post.trade_status = trade_status
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

    # -- 장소별 추억 타임라인 ---------------------------------------------------

    async def timeline(
        self, db: AsyncSession, *, region: str, board: str = "memory", viewer_id: int | None = None
    ) -> list[CommunityPostResponse]:
        """추억 게시판 글을 연도순(오래된 → 최신)으로 묶어 보여준다. 페이지네이션
        없이 한 번에 최대 200개를 가져온다 — 지금 규모에서 한 지역의 추억 글이
        그보다 많아질 일은 당분간 없고, 있더라도 타임라인은 "쭉 훑어보는" 화면이라
        더보기 버튼을 넣는 게 오히려 몰입을 깬다."""
        blocked = await self._blocked_ids(db, viewer_id)
        stmt = (
            select(CommunityPost, User.nickname)
            .join(User, User.id == CommunityPost.user_id)
            .where(CommunityPost.region == region, CommunityPost.board == board, CommunityPost.hidden.is_(False))
        )
        if blocked:
            stmt = stmt.where(CommunityPost.user_id.not_in(blocked))
        stmt = stmt.order_by(
            CommunityPost.memory_year.is_(None), CommunityPost.memory_year.asc(), CommunityPost.created_at.asc()
        ).limit(200)
        result = await db.execute(stmt)
        return [self._to_response(post, author_nickname=nickname) for post, nickname in result.all()]

    # -- 모교 커뮤니티(동창찾기) -------------------------------------------------

    async def search_schools(self, query: str) -> list[SchoolSearchResult]:
        """모교 검색 — 카카오 카테고리 코드(SC4=학교)로 필터링해 다른 지역/장소가 섞이지 않게 한다."""
        places = await self._kakao_local_service.search_schools(query, limit=8)
        return [
            SchoolSearchResult(id=place["id"] or place["name"], name=place["name"], address=place["address"])
            for place in places
            if place.get("name")
        ]

    async def active_authors(self, db: AsyncSession, user: User, *, region: str) -> list[NeighborResponse]:
        """"동창찾기" 등 학교처럼 home_region 개념이 없는 스코프에서 쓴다 — 내
        동네 설정과 무관하게, 이 지역(스코프) 문자열에 실제로 글을 쓴 사람들을
        글 수 순으로 보여준다."""
        blocked = await self._blocked_ids(db, user.id)
        stmt = (
            select(User.id, User.nickname, User.profile_image_url, func.count().label("post_count"))
            .join(CommunityPost, CommunityPost.user_id == User.id)
            .where(CommunityPost.region == region, CommunityPost.hidden.is_(False), User.id != user.id)
            .group_by(User.id)
        )
        if blocked:
            stmt = stmt.where(User.id.not_in(blocked))
        rows = await db.execute(stmt.order_by(desc("post_count"), User.nickname))
        return [
            NeighborResponse(user_id=row[0], nickname=row[1], profile_image_url=row[2], post_count=row[3])
            for row in rows.all()
        ]
