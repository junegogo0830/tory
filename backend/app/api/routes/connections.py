from fastapi import APIRouter, Depends, Query

from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.connections import (
    ConnectionRequestCreate,
    ConnectionRequestRespond,
    ConnectionRequestResponse,
    DirectMessageCreate,
    DirectMessageResponse,
)
from ...services.connections import ConnectionService
from ..deps import get_current_user

router = APIRouter(prefix="/api/connections", tags=["connections"])
_service = ConnectionService()


@router.post("", response_model=ConnectionRequestResponse)
async def send_connection_request(
    body: ConnectionRequestCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ConnectionRequestResponse:
    return await _service.send_request(db, user, body.recipient_id, body.message)


@router.post("/{request_id}/respond", response_model=ConnectionRequestResponse)
async def respond_connection_request(
    request_id: int,
    body: ConnectionRequestRespond,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ConnectionRequestResponse:
    return await _service.respond(db, user, request_id, body.accept)


@router.get("/requests", response_model=list[ConnectionRequestResponse])
async def list_connection_requests(
    direction: str = Query("received", pattern="^(received|sent)$"),
    status: str | None = Query(None, pattern="^(pending|accepted|declined)$"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[ConnectionRequestResponse]:
    return await _service.list_requests(db, user, direction=direction, status=status)


@router.get("", response_model=list[ConnectionRequestResponse])
async def list_connections(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[ConnectionRequestResponse]:
    return await _service.list_connections(db, user)


@router.get("/{connection_id}/messages", response_model=list[DirectMessageResponse])
async def list_messages(
    connection_id: int,
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[DirectMessageResponse]:
    return await _service.list_messages(db, user, connection_id, offset=offset)


@router.post("/{connection_id}/messages", response_model=DirectMessageResponse)
async def send_message(
    connection_id: int,
    body: DirectMessageCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> DirectMessageResponse:
    return await _service.send_message(db, user, connection_id, body.body)
