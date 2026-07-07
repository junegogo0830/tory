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
