import datetime

from fastapi import HTTPException
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db.models import ConnectionRequest, DirectMessage, User
from ..models.connections import ConnectionRequestResponse, DirectMessageResponse

_MAX_MESSAGE_LENGTH = 1000


class ConnectionService:
    """연결 요청 → 수락 → 메시지. 수락(accepted)되기 전엔 메시지를 주고받을 수 없다."""

    async def _connection(self, db: AsyncSession, connection_id: int) -> ConnectionRequest:
        connection = await db.get(ConnectionRequest, connection_id)
        if connection is None:
            raise HTTPException(404, "존재하지 않는 연결이에요")
        return connection

    def _to_response(
        self, connection: ConnectionRequest, *, requester: User, recipient: User, viewer_id: int
    ) -> ConnectionRequestResponse:
        is_requester = viewer_id == connection.requester_id
        other = recipient if is_requester else requester
        return ConnectionRequestResponse(
            id=connection.id,
            requester_id=connection.requester_id,
            recipient_id=connection.recipient_id,
            other_user_id=other.id,
            other_nickname=other.nickname,
            other_profile_image_url=other.profile_image_url,
            is_requester=is_requester,
            message=connection.message,
            status=connection.status,
            created_at=connection.created_at,
            responded_at=connection.responded_at,
        )

    async def _to_response_with_lookup(
        self, db: AsyncSession, connection: ConnectionRequest, *, viewer_id: int
    ) -> ConnectionRequestResponse:
        requester = await db.get(User, connection.requester_id)
        recipient = await db.get(User, connection.recipient_id)
        return self._to_response(connection, requester=requester, recipient=recipient, viewer_id=viewer_id)

    async def send_request(
        self, db: AsyncSession, requester: User, recipient_id: int, message: str | None
    ) -> ConnectionRequestResponse:
        if recipient_id == requester.id:
            raise HTTPException(422, "자기 자신에게는 연결 요청을 보낼 수 없어요")
        recipient = await db.get(User, recipient_id)
        if recipient is None:
            raise HTTPException(404, "존재하지 않는 사용자예요")

        existing = await db.scalar(
            select(ConnectionRequest).where(
                or_(
                    (ConnectionRequest.requester_id == requester.id) & (ConnectionRequest.recipient_id == recipient_id),
                    (ConnectionRequest.requester_id == recipient_id) & (ConnectionRequest.recipient_id == requester.id),
                )
            )
        )
        if existing is not None and existing.status in ("pending", "accepted"):
            raise HTTPException(422, "이미 연결 요청이 있어요")
        if existing is not None:
            # 예전에 거절된 요청이면 다시 pending으로 되살린다(중복 행을 만들지 않는다 — unique 제약).
            existing.requester_id = requester.id
            existing.recipient_id = recipient_id
            existing.message = message
            existing.status = "pending"
            existing.responded_at = None
            connection = existing
        else:
            connection = ConnectionRequest(requester_id=requester.id, recipient_id=recipient_id, message=message)
            db.add(connection)
        await db.commit()
        await db.refresh(connection)
        return await self._to_response_with_lookup(db, connection, viewer_id=requester.id)

    async def respond(self, db: AsyncSession, user: User, request_id: int, accept: bool) -> ConnectionRequestResponse:
        connection = await self._connection(db, request_id)
        if connection.recipient_id != user.id:
            raise HTTPException(403, "받은 사람만 응답할 수 있어요")
        if connection.status != "pending":
            raise HTTPException(422, "이미 처리된 요청이에요")
        connection.status = "accepted" if accept else "declined"
        connection.responded_at = datetime.datetime.now(datetime.timezone.utc)
        await db.commit()
        return await self._to_response_with_lookup(db, connection, viewer_id=user.id)

    async def list_requests(
        self, db: AsyncSession, user: User, *, direction: str, status: str | None = None
    ) -> list[ConnectionRequestResponse]:
        column = ConnectionRequest.recipient_id if direction == "received" else ConnectionRequest.requester_id
        stmt = select(ConnectionRequest).where(column == user.id)
        if status:
            stmt = stmt.where(ConnectionRequest.status == status)
        stmt = stmt.order_by(ConnectionRequest.created_at.desc())
        rows = (await db.execute(stmt)).scalars().all()
        return [await self._to_response_with_lookup(db, c, viewer_id=user.id) for c in rows]

    async def list_connections(self, db: AsyncSession, user: User) -> list[ConnectionRequestResponse]:
        stmt = select(ConnectionRequest).where(
            ConnectionRequest.status == "accepted",
            or_(ConnectionRequest.requester_id == user.id, ConnectionRequest.recipient_id == user.id),
        ).order_by(ConnectionRequest.responded_at.desc())
        rows = (await db.execute(stmt)).scalars().all()
        return [await self._to_response_with_lookup(db, c, viewer_id=user.id) for c in rows]

    async def _accepted_connection_for(self, db: AsyncSession, user: User, connection_id: int) -> ConnectionRequest:
        connection = await self._connection(db, connection_id)
        if user.id not in (connection.requester_id, connection.recipient_id):
            raise HTTPException(403, "참여자만 볼 수 있어요")
        if connection.status != "accepted":
            raise HTTPException(422, "연결이 수락된 뒤에만 대화할 수 있어요")
        return connection

    async def send_message(self, db: AsyncSession, user: User, connection_id: int, body: str) -> DirectMessageResponse:
        await self._accepted_connection_for(db, user, connection_id)
        message = DirectMessage(connection_id=connection_id, sender_id=user.id, body=body.strip()[:_MAX_MESSAGE_LENGTH])
        db.add(message)
        await db.commit()
        await db.refresh(message)
        return DirectMessageResponse(
            id=message.id, connection_id=connection_id, sender_id=user.id, body=message.body,
            created_at=message.created_at, is_mine=True,
        )

    async def list_messages(
        self, db: AsyncSession, user: User, connection_id: int, *, limit: int = 50, offset: int = 0
    ) -> list[DirectMessageResponse]:
        await self._accepted_connection_for(db, user, connection_id)
        rows = await db.execute(
            select(DirectMessage)
            .where(DirectMessage.connection_id == connection_id)
            .order_by(DirectMessage.created_at)
            .offset(offset)
            .limit(limit)
        )
        return [
            DirectMessageResponse(
                id=m.id, connection_id=m.connection_id, sender_id=m.sender_id, body=m.body,
                created_at=m.created_at, is_mine=m.sender_id == user.id,
            )
            for m in rows.scalars().all()
        ]
