import datetime

from pydantic import BaseModel, Field, field_validator


class SavedLocationSummary(BaseModel):
    id: str
    name: str
    region: str


class OnboardingRequest(BaseModel):
    # 선택 입력 — 건너뛰기도 이 엔드포인트를 age_group=None으로 호출해 완료
    # 처리한다(거주지/살았던 곳은 이미 있는 community/saved-locations 엔드포인트를
    # 프론트가 따로 호출한다).
    age_group: str | None = None


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
    user_id: int
    display_name: str
    tagline: str
    # 카카오 로그인 시 받아온 사진이거나, 프로필 수정에서 직접 올린 사진.
    profile_image_url: str | None = None
    # 통계 3칸 — 등록한 코스 커스텀 / 저장(북마크)한 코스 / 게시판 무관 내가 쓴 글.
    registered_course_count: int
    saved_course_count: int
    post_count: int
    saved_locations: list[SavedLocationSummary]
    # 커뮤니티 탭에서 설정한 "내 동네". 없으면 아직 설정 전이라는 뜻.
    home_region: str | None = None
    age_group: str | None = None
    gender: str | None = None
    friend_finder_enabled: bool = True
    full_name: str | None = None
    phone_number: str | None = None
    # 첫 로그인 온보딩(연령대/거주지/살았던 곳)을 완료했거나 건너뛰었으면 true.
    # false면 AppShell이 온보딩 화면을 띄운다.
    onboarding_completed: bool = False
    # 자체 회원가입(아이디+비밀번호) 계정이면 true — 카카오 로그인 계정은 비밀번호가
    # 없어 false다. 프론트가 "비밀번호 변경" 메뉴를 보여줄지 여기로 판단한다.
    has_password: bool = False


class ProfileInfoUpdateRequest(BaseModel):
    """프로필 "정보 수정" 화면 — 전부 선택 입력(보낸 필드만 바꾼다)."""

    gender: str | None = None
    full_name: str | None = Field(default=None, max_length=40)
    phone_number: str | None = Field(default=None, max_length=20)
    friend_finder_enabled: bool | None = None


class SavedCourseCreateRequest(BaseModel):
    course_type: str = Field(pattern="^(generated|custom)$")
    course_id: str = Field(min_length=1, max_length=50)


class SavedCourseResponse(BaseModel):
    """저장(북마크)한 코스 — 생성 코스/커스텀 코스를 한 모양으로 평평하게 만든다."""

    course_type: str  # "generated" | "custom"
    course_id: str
    title: str
    category: str | None = None
    thumbnail_url: str | None = None
    place_count: int
    saved_at: datetime.datetime


class RecordCourseViewRequest(BaseModel):
    course_type: str = Field(pattern="^(generated|custom)$")
    course_id: str = Field(min_length=1, max_length=50)


class RecentCourseResponse(BaseModel):
    """홈 "이어보기" — 마지막으로 열어본 코스 하나."""

    course_type: str  # "generated" | "custom"
    course_id: str
    title: str
    category: str | None = None
    thumbnail_url: str | None = None
    place_count: int
    viewed_at: datetime.datetime
