from pydantic import BaseModel


class HighlightCardResponse(BaseModel):
    id: str
    title: str
    region: str
    image_url: str
    category: str
