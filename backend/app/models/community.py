import datetime

from pydantic import BaseModel

# 지역별로 각각 운영되는 4개 게시판. region+board 조합이 하나의 "게시판"이다.
COMMUNITY_BOARDS = ("free", "memory", "resident", "info")


class CommunityPostResponse(BaseModel):
    id: int
    author_nickname: str
    region: str
    board: str
    title: str | None = None
    location_id: str | None = None
    photo_url: str | None = None
    caption: str | None = None
    memory_year: int | None = None
    created_at: datetime.datetime


class RegionByCoordsResponse(BaseModel):
    region: str | None


class HomeRegionRequest(BaseModel):
    region: str


class HomeRegionResponse(BaseModel):
    region: str | None
