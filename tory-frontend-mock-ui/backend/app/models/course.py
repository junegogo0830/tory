from pydantic import BaseModel


class CourseResponse(BaseModel):
    id: str
    title: str
    description: str
    sentiment_score: float
    stops: list[str]
    duration_label: str
