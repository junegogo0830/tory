from pydantic import BaseModel


class TopAttractionResponse(BaseModel):
    rank: int
    id: str
    name: str
    region: str
    image_url: str | None = None


class RestaurantItemResponse(BaseModel):
    id: str
    name: str
    region: str
    image_url: str | None = None


class RestaurantCategoryResponse(BaseModel):
    category: str
    headline: str
    items: list[RestaurantItemResponse]


class KakaoRestaurantResponse(BaseModel):
    """카카오맵 기반 맛집 — 카카오 로컬 API엔 사진 필드가 없어 image_url이 없다."""

    id: str
    name: str
    category: str
    address: str
    distance_m: int | None = None
