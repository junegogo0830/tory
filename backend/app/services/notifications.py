from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db.models import CommunityPost, Notification, User
from ..models.notifications import NotificationResponse


class NotificationService:
    """댓글/좋아요 알림. 좋아요는 반복 토글로 스팸이 되기 쉬워, 같은 글에 이미 읽지
    않은 좋아요 알림이 있으면 새로 만들지 않는다(댓글은 매번 새 알림)."""

    async def notify_comment(
        self, db: AsyncSession, *, post: CommunityPost, actor: User, comment_id: int
    ) -> None:
        if post.user_id == actor.id:
            return
        recipient = await db.get(User, post.user_id)
        if recipient is None or not recipient.notify_on_comment:
            return
        db.add(
            Notification(
                user_id=post.user_id,
                type="comment",
                actor_user_id=actor.id,
                actor_nickname=actor.nickname,
                post_id=post.id,
                post_title=post.title,
                comment_id=comment_id,
            )
        )
        await db.commit()

    async def notify_reply(
        self, db: AsyncSession, *, post: CommunityPost, actor: User, comment_id: int, reply_to: User
    ) -> None:
        """답글이 달렸을 때 원 댓글 작성자에게 알림. 글쓴이 알림(notify_comment)과는
        별개 — 답글 대상이 글쓴이 본인이면 이미 notify_comment가 알림을 만들었으니
        중복 알림을 만들지 않는다."""
        if reply_to.id == actor.id or reply_to.id == post.user_id:
            return
        if not reply_to.notify_on_comment:
            return
        db.add(
            Notification(
                user_id=reply_to.id,
                type="comment",
                actor_user_id=actor.id,
                actor_nickname=actor.nickname,
                post_id=post.id,
                post_title=post.title,
                comment_id=comment_id,
            )
        )
        await db.commit()

    async def notify_like(self, db: AsyncSession, *, post: CommunityPost, actor: User) -> None:
        if post.user_id == actor.id:
            return
        recipient = await db.get(User, post.user_id)
        if recipient is None or not recipient.notify_on_like:
            return
        existing = await db.execute(
            select(Notification.id).where(
                Notification.user_id == post.user_id,
                Notification.type == "like",
                Notification.post_id == post.id,
                Notification.actor_user_id == actor.id,
                Notification.is_read.is_(False),
            )
        )
        if existing.scalar_one_or_none() is not None:
            return
        db.add(
            Notification(
                user_id=post.user_id,
                type="like",
                actor_user_id=actor.id,
                actor_nickname=actor.nickname,
                post_id=post.id,
                post_title=post.title,
            )
        )
        await db.commit()

    async def list_notifications(
        self, db: AsyncSession, user: User, *, limit: int = 30, offset: int = 0
    ) -> list[NotificationResponse]:
        rows = await db.execute(
            select(Notification)
            .where(Notification.user_id == user.id)
            .order_by(desc(Notification.created_at), desc(Notification.id))
            .limit(limit)
            .offset(offset)
        )
        return [NotificationResponse.model_validate(n, from_attributes=True) for n in rows.scalars().all()]

    async def unread_count(self, db: AsyncSession, user: User) -> int:
        result = await db.execute(
            select(func.count())
            .select_from(Notification)
            .where(Notification.user_id == user.id, Notification.is_read.is_(False))
        )
        return result.scalar_one()

    async def mark_read(self, db: AsyncSession, user: User, notification_id: int) -> None:
        notification = await db.get(Notification, notification_id)
        if notification is None or notification.user_id != user.id:
            return
        notification.is_read = True
        await db.commit()

    async def mark_all_read(self, db: AsyncSession, user: User) -> None:
        rows = await db.execute(select(Notification).where(Notification.user_id == user.id, Notification.is_read.is_(False)))
        for notification in rows.scalars().all():
            notification.is_read = True
        await db.commit()
