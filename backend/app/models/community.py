import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

# 지역별로 각각 운영되는 5개 게시판. region+board 조합이 하나의 "게시판"이다.
# "timecapsule"은 reveal_at이 지나기 전엔 내용이 가려지는 특수 게시판이다.
COMMUNITY_BOARDS = ("free", "memory", "resident", "info", "timecapsule")

# 블록 하나당 본문 텍스트 길이 상한(기존 caption 상한과 맞춘다) / 글 하나에 들어갈 수 있는 블록 총 개수 상한.
MAX_BLOCK_TEXT_LENGTH = 2000
MAX_CONTENT_BLOCKS = 40


class ContentBlockResponse(BaseModel):
    """블로그 스타일 글쓰기의 본문 블록 하나. text/image가 등장한 순서 그대로 배열로 내려간다."""

    type: Literal['text', 'image']
    text: str | None = None
    image_url: str | None = None


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
    # 블로그 스타일로 작성된 글만 채워진다. None이면 위 caption/photo_urls로 렌더링하는 옛 글.
    content_blocks: list[ContentBlockResponse] | None = None
    memory_year: int | None = None
    # 타임캡슐 전용. 다른 게시판은 항상 None/True.
    reveal_at: datetime.datetime | None = None
    revealed: bool = True
    # 주민 게시판(중고거래 스타일) 전용 — 다른 게시판은 항상 None.
    price: int | None = None
    trade_status: str | None = None
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
    caption: str = Field(max_length=2000)


TRADE_STATUSES = ("판매중", "예약중", "거래완료")


class TradeStatusUpdateRequest(BaseModel):
    trade_status: str

    @field_validator('trade_status')
    @classmethod
    def valid_status(cls, value):
        if value not in TRADE_STATUSES:
            raise ValueError('올바른 거래 상태를 선택해주세요')
        return value


class RegionStatsResponse(BaseModel):
    """지역 커뮤니티 가입 확인 화면에 보여주는 통계 — "OO구엔 이미 N명이
    함께하고 있어요" 같은 소속감을 주는 문구에 쓴다."""

    region: str
    member_count: int
    post_count: int


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


class SchoolSearchResult(BaseModel):
    """모교 검색 결과 — 카카오 로컬 키워드 검색을 그대로 감싼다(학교 전용 API가
    따로 있는 게 아니라, 일반 장소 검색으로 "OO초등학교" 같은 이름을 찾는 것)."""

    id: str
    name: str
    address: str
