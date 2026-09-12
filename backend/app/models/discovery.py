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
