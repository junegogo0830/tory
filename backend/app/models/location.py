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
    # image_url이 이 장소 자신의 사진이 아니라 주변/대표 관광지 사진으로 대체된
    # 경우에만 그 관광지 이름이 채워진다. 프론트엔드는 이 값이 있으면 "OO 사진이
    # 없어 가까운 XX 사진을 보여드려요" 같은 안내를 노출해야 한다.
    image_source_name: str | None = None
    # 위치 기반 코스 추천(주변 실제 장소 검색)에 쓰는 좌표. 없으면 코스 생성이
    # 좌표 기반 검색을 못 하고 빈 결과로 폴백한다.
    latitude: float | None = None
    longitude: float | None = None


class PopularLocationResponse(LocationResponse):
    """둘러보기 탭 "다른 사람들이 둘러본 골목" — 실제로 저장(찜)한 사용자 수 기준."""

    saved_by_count: int
