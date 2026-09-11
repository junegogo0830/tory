from pydantic import BaseModel


class LocationResponse(BaseModel):
    id: str
    name: str
    region: str
    description: str
    past_year: int
    current_year: int
    is_cold_spot: bool = False
    source: str = "mock"
    # 등록된 관광지와 매칭되면 TourAPI의 실제 현재 사진, 없으면 None
    # (프론트엔드는 None일 때 보유 정적 이미지로 폴백한다).
    image_url: str | None = None
    # 위치 기반 코스 추천(주변 실제 장소 검색)에 쓰는 좌표. 없으면 코스 생성이
    # 좌표 기반 검색을 못 하고 빈 결과로 폴백한다.
    latitude: float | None = None
    longitude: float | None = None
