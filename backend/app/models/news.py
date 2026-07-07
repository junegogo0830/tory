from pydantic import BaseModel


class NewsItemResponse(BaseModel):
    id: str
    year: int
    title: str
    source: str
    summary: str
