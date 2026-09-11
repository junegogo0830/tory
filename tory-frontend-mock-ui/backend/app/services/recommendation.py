from ..models.course import CourseResponse
from .sentiment_client import SentimentClient

# TODO: TourAPI 코스/카테고리 데이터 + SentimentClient 실시간 결합으로 대체.
_MOCK_COURSES: dict[str, list[CourseResponse]] = {
    "suncheon-jeonpo": [
        CourseResponse(
            id="c1", title="순천만 노을 산책 코스",
            description="어릴 적 놀던 골목에서 순천만 습지까지 이어지는 감성 코스",
            sentiment_score=0.86,
            stops=["전포동 골목", "순천만국가정원", "순천만습지 노을전망대"],
            duration_label="약 3시간",
        ),
        CourseResponse(
            id="c2", title="옛 시장 미식 코스",
            description="추억의 분식집부터 최근 인기 맛집까지",
            sentiment_score=0.74,
            stops=["전포동 골목시장", "아랫장 국밥거리"],
            duration_label="약 2시간",
        ),
    ],
    "gunsan-jungang": [
        CourseResponse(
            id="c3", title="근대문화유산 골목 코스",
            description="중앙로 상가에서 이어지는 군산 근대역사 탐방",
            sentiment_score=0.81,
            stops=["중앙로 상가", "군산근대역사박물관", "동국사"],
            duration_label="약 2.5시간",
        ),
    ],
    "yeongwol-jang": [],
}


class RecommendationService:
    """감성분석 결합 관광 코스 추천 서비스 (목 데이터)."""

    def __init__(self, sentiment_client: SentimentClient | None = None) -> None:
        self._sentiment_client = sentiment_client or SentimentClient()

    async def get_courses_by_location(self, location_id: str) -> list[CourseResponse]:
        return _MOCK_COURSES.get(location_id, [])

    async def get_all_courses(self) -> list[CourseResponse]:
        return [course for courses in _MOCK_COURSES.values() for course in courses]

    async def get_course_by_id(self, course_id: str) -> CourseResponse | None:
        for courses in _MOCK_COURSES.values():
            for course in courses:
                if course.id == course_id:
                    return course
        return None
