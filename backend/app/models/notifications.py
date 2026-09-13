import datetime
from typing import Literal

from pydantic import BaseModel


class NotificationResponse(BaseModel):
    id: int
    type: Literal["comment", "like"]
    actor_nickname: str
    post_id: int
    post_title: str | None = None
    comment_id: int | None = None
    is_read: bool
    created_at: datetime.datetime


class UnreadCountResponse(BaseModel):
    count: int


class NotificationSettingsResponse(BaseModel):
    notify_on_comment: bool
    notify_on_like: bool


class NotificationSettingsRequest(BaseModel):
    notify_on_comment: bool
    notify_on_like: bool
