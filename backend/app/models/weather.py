from pydantic import BaseModel


class WeatherResponse(BaseModel):
    # {clear|cloudy|overcast|rain|snow}_{day|night} — 모든 날씨가 낮/밤으로 나뉜다.
    condition: str
    temperature: float
    description: str
    is_daytime: bool
