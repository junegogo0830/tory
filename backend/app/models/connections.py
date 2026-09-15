import datetime
from typing import Literal

from pydantic import BaseModel, Field

ConnectionStatus = Literal["pending", "accepted", "declined"]


class ConnectionRequestCreate(BaseModel):
    recipient_id: int
    message: str | None = Field(default=None, max_length=300)


class ConnectionRequestRespond(BaseModel):
    accept: bool


class ConnectionRequestResponse(BaseModel):
    id: int
    requester_id: int
    recipient_id: int
    # 보는 사람(viewer) 기준 "상대방" — 프론트가 내 user_id를 따로 몰라도 목록/채팅
    # 화면에 바로 쓸 수 있게 서버가 미리 계산해서 내려준다(DirectMessageResponse의
    # is_mine과 같은 패턴).
    other_user_id: int
    other_nickname: str
    other_profile_image_url: str | None = None
    is_requester: bool
    message: str | None = None
    status: ConnectionStatus
    created_at: datetime.datetime
    responded_at: datetime.datetime | None = None


class DirectMessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=1000)


class DirectMessageResponse(BaseModel):
    id: int
    connection_id: int
    sender_id: int
    body: str
    created_at: datetime.datetime
    is_mine: bool = False
