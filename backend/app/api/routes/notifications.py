from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.notifications import (
    NotificationResponse,
    NotificationSettingsRequest,
    NotificationSettingsResponse,
    UnreadCountResponse,
)
from ...services.notifications import NotificationService
from ..deps import get_current_user

router = APIRouter(prefix="/api/notifications", tags=["notifications"])
_notification_service = NotificationService()


@router.get("", response_model=list[NotificationResponse])
async def list_notifications(
    limit: int = Query(30, ge=1, le=50),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[NotificationResponse]:
    return await _notification_service.list_notifications(db, user, limit=limit, offset=offset)


@router.get("/unread-count", response_model=UnreadCountResponse)
async def unread_count(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> UnreadCountResponse:
    return UnreadCountResponse(count=await _notification_service.unread_count(db, user))


@router.post("/{notification_id}/read", status_code=204)
async def mark_read(
    notification_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> None:
    await _notification_service.mark_read(db, user, notification_id)


@router.post("/read-all", status_code=204)
async def mark_all_read(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)) -> None:
    await _notification_service.mark_all_read(db, user)


@router.get("/settings", response_model=NotificationSettingsResponse)
async def get_settings(user: User = Depends(get_current_user)) -> NotificationSettingsResponse:
    return NotificationSettingsResponse(
        notify_on_comment=user.notify_on_comment, notify_on_like=user.notify_on_like
    )


@router.patch("/settings", response_model=NotificationSettingsResponse)
async def update_settings(
    body: NotificationSettingsRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> NotificationSettingsResponse:
    user.notify_on_comment = body.notify_on_comment
    user.notify_on_like = body.notify_on_like
    await db.commit()
    return NotificationSettingsResponse(
        notify_on_comment=user.notify_on_comment, notify_on_like=user.notify_on_like
    )
