import datetime

from pydantic import BaseModel


class CommunityPostResponse(BaseModel):
    id: int
    author_nickname: str
    region: str
    location_id: str | None = None
    photo_url: str
    caption: str | None = None
    memory_year: int | None = None
    created_at: datetime.datetime


class RegionByCoordsResponse(BaseModel):
    region: str | None


class HomeRegionRequest(BaseModel):
    region: str


class HomeRegionResponse(BaseModel):
    region: str | None
