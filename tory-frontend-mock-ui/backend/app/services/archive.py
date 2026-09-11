from ..models.news import NewsItemResponse

# TODO: 네이버 뉴스 라이브러리 / 국가기록원 연동으로 대체.
_MOCK_NEWS: dict[str, list[NewsItemResponse]] = {
    "suncheon-jeonpo": [
        NewsItemResponse(
            id="n1", year=1998, title="순천 전포동, 신설 초등학교 개교",
            source="전남매일", summary="학생 수 증가에 따라 전포동에 새 초등학교가 문을 열었다.",
        ),
        NewsItemResponse(
            id="n2", year=2004, title="전포동 골목시장 활성화 사업 추진",
            source="순천신문", summary="지역 상인회를 중심으로 골목시장 환경 개선 사업이 시작됐다.",
        ),
        NewsItemResponse(
            id="n3", year=2015, title="전포동 재개발 논의 본격화",
            source="순천신문", summary="노후 주택가 재개발을 위한 주민 설명회가 열렸다.",
        ),
    ],
    "gunsan-jungang": [
        NewsItemResponse(
            id="n4", year=2003, title="군산 중앙로 상권, 주말 유동인구 최대",
            source="군산일보", summary="중앙로 일대 상가에 주말마다 학생들이 몰리며 상권이 활기를 띠었다.",
        ),
    ],
    # 콜드스팟 예시: 뉴스 아카이브가 비어있어 빈 상태 폴백을 확인할 수 있다.
    "yeongwol-jang": [],
}


class ArchiveService:
    """장소별 그 시절 지역 뉴스 아카이브 서비스 (목 데이터)."""

    async def get_news_by_location(self, location_id: str) -> list[NewsItemResponse]:
        items = _MOCK_NEWS.get(location_id, [])
        return sorted(items, key=lambda item: item.year)
