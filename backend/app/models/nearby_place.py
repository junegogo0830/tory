from pydantic import BaseModel


class NearbyPlace(BaseModel):
    name: str
    category: str
    distance_m: int | None = None
    address: str
    latitude: float | None = None
    longitude: float | None = None
