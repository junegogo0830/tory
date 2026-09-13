from pydantic import BaseModel


class NewsItemResponse(BaseModel):
    id: str
    year: int
    title: str
    source: str
    summary: str
    # 정확한 발행일(YYYY-MM-DD). 큐레이션 목 데이터처럼 연도만 아는 경우 None —
    # 이때는 화면/정렬 모두 year로 폴백한다.
    published_at: str | None = None
    # 원문 기사 링크. 있으면 화면에서 "기사 보기"로 탭해 열 수 있다.
    url: str | None = None


class RegionStoryResponse(BaseModel):
    # Claude가 웹 검색으로 찾은 내용을 자연어로 종합한 "그 시절" 이야기.
    # 찾은 게 없으면 이 응답 자체가 아니라 null(경로 참고)을 내려준다.
    summary: str
