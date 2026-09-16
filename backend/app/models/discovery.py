from pydantic import BaseModel


class TopAttractionResponse(BaseModel):
    rank: int
    id: str
    name: str
    region: str
    image_url: str | None = None
    # image_url이 구글 플레이스 사진일 때만 채워진다 — 구글 이용약관상 사진을
    # 보여주려면 기여자 출처 표기를 같이 보여줘야 한다.
    photo_attribution_name: str | None = None
    photo_attribution_url: str | None = None


class RestaurantItemResponse(BaseModel):
    id: str
    name: str
    region: str
    image_url: str | None = None
    photo_attribution_name: str | None = None
    photo_attribution_url: str | None = None


class RestaurantCategoryResponse(BaseModel):
    category: str
    headline: str
    items: list[RestaurantItemResponse]


class KakaoRestaurantResponse(BaseModel):
    """카카오맵 기반 맛집.

    카카오 로컬 API 응답 자체엔 사진·평점·리뷰 수 필드가 없다(실제 호출로 확인 —
    id/place_name/category_name/address_name/road_address_name/phone/place_url/
    x/y/distance만 온다). 그래서:
    - image_url은 같은 이름으로 TourAPI에 등록된 관광지/음식점이 있을 때만
      보강되는 값이고(없으면 None — 프론트엔드는 아이콘 배지로 폴백한다),
    - "인기순" 대신 카카오 자체 관련도(sort=accuracy)를 쓰고,
    - 실제 평점·리뷰는 place_url로 카카오맵 원본 페이지에 링크해 보여준다.
    """

    id: str
    name: str
    category: str
    # 한식/중식/일식/양식/디저트/기타로 뭉뚱그린 큰 분류 — 지역 캐러셀의 카테고리
    # 토글이 쓴다.
    cuisine: str = "기타"
    address: str
    distance_m: int | None = None
    image_url: str | None = None
    photo_attribution_name: str | None = None
    photo_attribution_url: str | None = None
    phone: str | None = None
    place_url: str | None = None
    latitude: float | None = None
    longitude: float | None = None
