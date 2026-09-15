from typing import Literal
from pydantic import BaseModel, Field

CourseCategory = Literal['산책', '역사', '미식', '문화', '자연', '가족']


class CourseGenerateRequest(BaseModel):
    region: str = Field(min_length=2, max_length=100)
    age_group: Literal['선택 안 함', '10대', '20대', '30대', '40대', '50대', '60대 이상'] = '선택 안 함'
    gender: Literal['선택 안 함', '여성', '남성', '기타'] = '선택 안 함'
    categories: list[CourseCategory] = Field(default_factory=lambda: ['산책'], min_length=1, max_length=6)
    weather_mode: Literal['current', 'clear', 'rain', 'snow', 'hot', 'cold'] = 'current'
    pace: Literal['여유롭게', '보통', '활기차게'] = '보통'
    duration_hours: int = Field(default=3, ge=1, le=8)


class CourseStop(BaseModel):
    name: str
    # 실제 등록된 장소와 매칭됐을 때만 채워진다 — 있으면 프론트에서 카카오맵
    # 길찾기 딥링크를 만들 수 있다. 큐레이션 코스의 일부 정류지(가상의 옛길
    # 골목 등)는 등록된 장소가 아니라 None으로 남을 수 있다.
    latitude: float | None = None
    longitude: float | None = None
    category: str = ''
    address: str = ''
    stay_minutes: int = 30
    # TourApiService.find_place_info로 보강된 정류지 사진 — 없으면 프론트가
    # 자체 폴백 아이콘을 보여준다.
    image_url: str | None = None


class CourseResponse(BaseModel):
    id: str
    title: str
    description: str
    sentiment_score: float
    stops: list[CourseStop]
    duration_label: str
    category: str
    image_url: str | None = None
    # 프론트가 "이 코스 주변 맛집" 등을 조회할 때 쓴다.
    location_id: str = ""
    region: str = ''
    weather_label: str = ''
    estimated_distance_km: float | None = None
    notes: list[str] = Field(default_factory=list)
    source: str = 'curated'
