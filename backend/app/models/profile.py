import datetime

from pydantic import BaseModel, Field, field_validator


class SavedLocationSummary(BaseModel):
    id: str
    name: str
    region: str


class NicknameUpdateRequest(BaseModel):
    nickname: str = Field(min_length=1, max_length=80)

    @field_validator('nickname')
    @classmethod
    def nonblank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError('닉네임을 입력해주세요')
        return value


class MyMemoryResponse(BaseModel):
    """"사진으로 남긴 추억" 목록 항목 — 내가 쓴 글 중 사진이 있는 것만."""

    id: int
    region: str
    board: str
    title: str | None = None
    photo_url: str
    caption: str | None = None
    memory_year: int | None = None
    created_at: datetime.datetime


class ProfileResponse(BaseModel):
    display_name: str
    tagline: str
    # 카카오 로그인 시 받아온 사진이거나, 프로필 수정에서 직접 올린 사진.
    profile_image_url: str | None = None
    saved_locations_count: int
    completed_courses_count: int
    memory_photo_count: int
    saved_locations: list[SavedLocationSummary]
    # 커뮤니티 탭에서 설정한 "내 동네". 없으면 아직 설정 전이라는 뜻.
    home_region: str | None = None
