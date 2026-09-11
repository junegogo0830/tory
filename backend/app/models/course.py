from pydantic import BaseModel


class CourseStop(BaseModel):
    name: str
    # 실제 등록된 장소와 매칭됐을 때만 채워진다 — 있으면 프론트에서 카카오맵
    # 길찾기 딥링크를 만들 수 있다. 큐레이션 코스의 일부 정류지(가상의 옛길
    # 골목 등)는 등록된 장소가 아니라 None으로 남을 수 있다.
    latitude: float | None = None
    longitude: float | None = None


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
