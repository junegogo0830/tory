import datetime

from pydantic import BaseModel, Field, field_validator

# 기존 추천 코스(CourseCategory, models/course.py)와 같은 카테고리 체계를 그대로
# 쓴다 — 커뮤니티에서 "코스 커스텀"으로 만든 코스도 결국 같은 코스 개념이라
# 카테고리를 따로 만들면 필터링/탐색이 두 갈래로 갈라진다.
CUSTOM_COURSE_CATEGORIES = ("산책", "역사", "미식", "문화", "자연", "가족")


class CustomCoursePlaceInput(BaseModel):
    """사용자가 검색해서 고른 장소 하나. source로 어느 검색(TourAPI/카카오맵)에서
    왔는지만 남기고, 나머지는 그 검색 결과를 그대로 스냅샷한다 — 원본이 나중에
    바뀌거나 삭제돼도 이 코스에 담긴 장소 정보는 그대로 남아야 하기 때문."""

    source: str = Field(pattern="^(tour|kakao)$")
    place_id: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=120)
    address: str = Field(default="", max_length=200)
    latitude: float | None = None
    longitude: float | None = None
    image_url: str | None = None
    # 이 장소에 대한 작성자의 짧은 코멘트 — 코스 하나짜리 소개(description)와
    # 별개로 장소마다 남길 수 있다.
    note: str | None = Field(default=None, max_length=300)


class CustomCoursePlaceResponse(CustomCoursePlaceInput):
    pass


class CustomCourseCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=60)
    category: str
    description: str | None = Field(default=None, max_length=300)
    places: list[CustomCoursePlaceInput] = Field(min_length=1, max_length=15)
    is_public: bool = True

    @field_validator("title")
    @classmethod
    def nonblank_title(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("제목을 입력해주세요")
        return value.strip()

    @field_validator("category")
    @classmethod
    def valid_category(cls, value: str) -> str:
        if value not in CUSTOM_COURSE_CATEGORIES:
            raise ValueError("올바른 카테고리를 선택해주세요")
        return value


class CustomCourseUpdateRequest(CustomCourseCreateRequest):
    """코스 수정 — 생성과 같은 필드를 그대로 전체 교체(PUT 방식)한다."""


class CustomCourseSummaryResponse(BaseModel):
    """목록 화면용 — 장소는 개수/썸네일만, 상세는 [CustomCourseResponse]에서."""

    id: int
    author_id: int
    author_nickname: str
    title: str
    category: str
    place_count: int
    thumbnail_url: str | None = None
    score: int = 0  # like_count - dislike_count
    like_count: int = 0
    dislike_count: int = 0
    comment_count: int = 0
    created_at: datetime.datetime


class CustomCourseResponse(BaseModel):
    id: int
    author_id: int
    author_nickname: str
    title: str
    category: str
    description: str | None = None
    places: list[CustomCoursePlaceResponse]
    like_count: int = 0
    dislike_count: int = 0
    comment_count: int = 0
    is_mine: bool = False
    is_public: bool = True
    # 로그인 사용자 기준 내 투표 상태: 1(추천)/-1(비추천)/0(안 함).
    my_vote: int = 0
    created_at: datetime.datetime


class CustomCourseVoteRequest(BaseModel):
    # 이미 누른 걸 다시 누르면 0으로 보내 취소한다(프론트가 토글 처리).
    value: int

    @field_validator("value")
    @classmethod
    def valid_value(cls, value: int) -> int:
        if value not in (-1, 0, 1):
            raise ValueError("value는 -1, 0, 1 중 하나여야 해요")
        return value


class CustomCourseCommentRequest(BaseModel):
    body: str = Field(min_length=1, max_length=300)

    @field_validator("body")
    @classmethod
    def nonblank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("내용을 입력해주세요")
        return value.strip()


class CustomCourseCommentResponse(BaseModel):
    id: int
    author_id: int
    author_nickname: str
    body: str
    is_mine: bool = False
    created_at: datetime.datetime


class KakaoPlaceSearchResult(BaseModel):
    """코스 커스텀에서 "카카오맵 기반"으로 장소를 검색할 때 쓰는 결과 —
    카카오 로컬 키워드/주소 검색을 그대로 감싼다."""

    id: str
    name: str
    address: str
    latitude: float
    longitude: float
