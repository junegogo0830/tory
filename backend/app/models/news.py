from pydantic import BaseModel


class NewsItemResponse(BaseModel):
    id: str
    year: int
    title: str
    source: str
    summary: str


class RegionStoryResponse(BaseModel):
    # Claude가 웹 검색으로 찾은 내용을 자연어로 종합한 "그 시절" 이야기.
    # 찾은 게 없으면 이 응답 자체가 아니라 null(경로 참고)을 내려준다.
    summary: str
