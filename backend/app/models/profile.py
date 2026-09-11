from pydantic import BaseModel


class SavedLocationSummary(BaseModel):
    id: str
    name: str
    region: str


class ProfileResponse(BaseModel):
    display_name: str
    tagline: str
    saved_locations_count: int
    completed_courses_count: int
    memory_photo_count: int
    saved_locations: list[SavedLocationSummary]
    # 커뮤니티 탭에서 설정한 "내 동네". 없으면 아직 설정 전이라는 뜻.
    home_region: str | None = None
