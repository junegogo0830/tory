from typing import Literal

from pydantic import BaseModel, Field, field_validator

MemoryAttributeType = Literal["region", "school", "place"]


class MemoryAttributeCreateRequest(BaseModel):
    type: MemoryAttributeType
    label: str = Field(min_length=1, max_length=100)
    # type="place"일 때만 의미가 있다 — 장소 검색 결과의 location_id(예: "tour-123",
    # "kakao-456")를 그대로 넘긴다. region/school은 항상 None.
    place_id: str | None = Field(default=None, max_length=120)
    start_year: int | None = None
    end_year: int | None = None

    @field_validator('label')
    @classmethod
    def strip_label(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError('이름을 입력해주세요')
        return value

    @field_validator('end_year')
    @classmethod
    def validate_year_range(cls, value: int | None, info) -> int | None:
        start = info.data.get('start_year')
        if value is not None and start is not None and value < start:
            raise ValueError('종료 연도가 시작 연도보다 빠를 수 없어요')
        return value


class MemoryAttributeResponse(BaseModel):
    id: int
    type: MemoryAttributeType
    label: str
    place_id: str | None = None
    start_year: int | None = None
    end_year: int | None = None


class MemorySearchFilter(BaseModel):
    """친구 찾기 검색 조건 하나 — MemoryAttributeCreateRequest와 모양은 같지만
    저장 없이 매칭에만 쓰인다(저장하려면 별도로 POST /attributes를 호출한다)."""

    type: MemoryAttributeType
    label: str = Field(min_length=1, max_length=100)
    place_id: str | None = Field(default=None, max_length=120)
    start_year: int | None = None
    end_year: int | None = None


class MemorySearchRequest(BaseModel):
    filters: list[MemorySearchFilter] = Field(min_length=1, max_length=20)


class MemoryMatchResponse(BaseModel):
    user_id: int
    nickname: str
    profile_image_url: str | None = None
    score: int
    reasons: list[str]


class MemoryOverlapResponse(BaseModel):
    count: int
    matches: list[MemoryMatchResponse]


class MemoryProfileResponse(BaseModel):
    user_id: int
    nickname: str
    profile_image_url: str | None = None
    attributes: list[MemoryAttributeResponse]
    course_count: int
    memory_post_count: int
    is_mine: bool
    connection_status: Literal["none", "pending_sent", "pending_received", "accepted"]
    connection_id: int | None = None
