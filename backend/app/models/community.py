import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

# 지역별로 각각 운영되는 4개 게시판. region+board 조합이 하나의 "게시판"이다.
COMMUNITY_BOARDS = ("free", "memory", "resident", "info")


class CommunityPostResponse(BaseModel):
    id: int
    author_id: int
    author_nickname: str
    region: str
    board: str
    title: str | None = None
    location_id: str | None = None
    # 대표(첫 번째) 사진 — 목록 카드는 이것만 쓴다. 하위 호환용으로 유지.
    photo_url: str | None = None
    # 전체 사진(여러 장 지원). 상세 화면 갤러리에서 쓴다.
    photo_urls: list[str] = Field(default_factory=list)
    caption: str | None = None
    memory_year: int | None = None
    created_at: datetime.datetime


class RegionByCoordsResponse(BaseModel):
    region: str | None


class HomeRegionRequest(BaseModel):
    region: str


class HomeRegionResponse(BaseModel):
    region: str | None


class CommentRequest(BaseModel):
    body: str = Field(min_length=1, max_length=500)
    # 답글이면 그 대상 댓글 id. 이미 답글인 댓글에 또 답글을 달면 서비스 레이어가
    # 그 댓글의 최상위 부모로 자동 승격해 1단계 스레드만 유지한다.
    parent_id: int | None = None

    @field_validator('body')
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError('내용을 입력해주세요')
        return value.strip()


class PostUpdateRequest(BaseModel):
    title: str = Field(max_length=120)
    caption: str = Field(max_length=500)


class CommentResponse(BaseModel):
    id: int
    author_id: int
    author_nickname: str
    body: str
    parent_id: int | None = None
    created_at: datetime.datetime
    is_mine: bool = False


class PostDetailResponse(CommunityPostResponse):
    is_mine: bool = False
    liked: bool = False
    like_count: int = 0
    comment_count: int = 0


class ReportRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=200)

    @field_validator('reason')
    @classmethod
    def nonblank(cls, value):
        if not value.strip():
            raise ValueError('신고 사유를 입력해주세요')
        return value.strip()


ReportTargetType = Literal["post", "comment"]


class BlockedUserResponse(BaseModel):
    user_id: int
    nickname: str


class NeighborResponse(BaseModel):
    user_id: int
    nickname: str
    profile_image_url: str | None = None
    post_count: int
