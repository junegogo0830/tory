import asyncio
import datetime

from ..core.season import current_season
from ..models.course import CourseResponse, CourseStop
from ..models.location import LocationResponse
from .course_generator import CourseGeneratorService
from .kakao_local import KakaoLocalService
from .sentiment_client import SentimentClient
from .tourapi import TourApiService

# TODO: 감성 점수는 SentimentClient(현재 placeholder)가 실제 학습된 모델로
# 교체되면 실시간 계산으로 대체한다. 코스 구성(정류지 순서·소요시간)은 옛길 팀
# 큐레이션 값 — image_url/정류지 좌표만 TourApiService로 실시간 보강한다.
#
# 이 딕셔너리는 옛길 팀이 손으로 다듬은 큐레이션 3곳(순천/군산/영월) 전용이다.
# 그 밖의 장소(검색으로 찾은 임의의 동네)는 CourseGeneratorService가 좌표 기반
# 실제 주변 장소 + LLM으로 그때그때 만든다 — get_courses_by_location 참고.
_MOCK_COURSES: dict[str, list[CourseResponse]] = {
    "suncheon-jeonpo": [
        CourseResponse(
            id="c1", title="순천만 노을 산책 코스", location_id="suncheon-jeonpo",
            description="어릴 적 놀던 골목에서 순천만 습지까지 이어지는 감성 코스",
            sentiment_score=0.86,
            stops=[
                CourseStop(name="저전동 골목"),
                CourseStop(name="순천만국가정원"),
                CourseStop(name="순천만습지 노을전망대"),
            ],
            duration_label="약 3시간",
            category="산책",
        ),
        CourseResponse(
            id="c2", title="옛 시장 미식 코스", location_id="suncheon-jeonpo",
            description="추억의 분식집부터 최근 인기 맛집까지",
            sentiment_score=0.74,
            stops=[CourseStop(name="저전동 골목시장"), CourseStop(name="아랫장 국밥거리")],
            duration_label="약 2시간",
            category="미식",
        ),
    ],
    "gunsan-jungang": [
        CourseResponse(
            id="c3", title="근대문화유산 골목 코스", location_id="gunsan-jungang",
            description="중앙로 상가에서 이어지는 군산 근대역사 탐방",
            sentiment_score=0.81,
            stops=[
                CourseStop(name="중앙로 상가"),
                CourseStop(name="군산근대역사박물관"),
                CourseStop(name="동국사"),
            ],
            duration_label="약 2.5시간",
            category="역사",
        ),
    ],
    "yeongwol-jang": [],
}


class RecommendationService:
    """감성분석 결합 관광 코스 추천 서비스.

    큐레이션 3곳은 손으로 다듬은 코스(사진·정류지 좌표만 실시간 보강), 그 밖의
    장소는 좌표 기반 실제 주변 장소 + LLM 생성 코스(계절별 캐싱)를 쓴다.
    """

    def __init__(
        self,
        sentiment_client: SentimentClient | None = None,
        tour_api_service: TourApiService | None = None,
        course_generator_service: CourseGeneratorService | None = None,
        kakao_local_service: KakaoLocalService | None = None,
    ) -> None:
        self._sentiment_client = sentiment_client or SentimentClient()
        self._tour_api_service = tour_api_service or TourApiService()
        self._course_generator_service = course_generator_service or CourseGeneratorService(
            tour_api_service=self._tour_api_service
        )
        self._kakao_local_service = kakao_local_service or KakaoLocalService()

    async def get_course_by_coords(self, latitude: float, longitude: float) -> CourseResponse | None:
        """"현재 위치" 코스. 등록된 장소가 아니어도 된다 — CourseGeneratorService는
        좌표만 있으면 되고 location이 진짜 관광지일 필요가 없다(id 형식을 검증하지
        않음). 좌표를 소수점 3자리(~111m)로 반올림해 기존 계절별 캐싱이 GPS
        지터로 매번 깨지지 않게 한다.
        """
        rounded_lat, rounded_lng = round(latitude, 3), round(longitude, 3)
        region = await self._kakao_local_service.reverse_geocode(rounded_lat, rounded_lng)
        current_year = datetime.date.today().year

        location = LocationResponse(
            id=f"coords-{rounded_lat},{rounded_lng}",
            name=region or "현재 위치",
            region=region or "",
            description="",
            past_year=current_year,
            current_year=current_year,
            source="coords",
            latitude=rounded_lat,
            longitude=rounded_lng,
        )

        course = await self._course_generator_service.generate_course(location, current_season())
        return await self._enrich_course(course) if course is not None else None

    async def get_courses_by_location(self, location_id: str) -> list[CourseResponse]:
        curated = _MOCK_COURSES.get(location_id)
        if curated is not None:
            return list(await asyncio.gather(*(self._enrich_course(c) for c in curated)))

        location = await self._tour_api_service.get_location_by_id(location_id)
        if location is None:
            return []

        course = await self._course_generator_service.generate_course(location, current_season())
        if course is None:
            return []
        return [await self._enrich_course(course)]

    async def get_all_courses(self) -> list[CourseResponse]:
        courses = [course for courses in _MOCK_COURSES.values() for course in courses]
        return list(await asyncio.gather(*(self._enrich_course(c) for c in courses)))

    async def get_course_by_id(self, course_id: str) -> CourseResponse | None:
        if course_id.startswith("llm-"):
            return await self._get_generated_course(course_id)

        for courses in _MOCK_COURSES.values():
            for course in courses:
                if course.id == course_id:
                    return await self._enrich_course(course)
        return None

    async def _get_generated_course(self, course_id: str) -> CourseResponse | None:
        # id 형식: "llm-{location_id}-{season}". location_id 자체에 하이픈이
        # 있을 수 있어(예: "tour-125555") 마지막 하이픈 기준으로만 나눈다.
        remainder = course_id.removeprefix("llm-")
        location_id, _, season = remainder.rpartition("-")
        if not location_id:
            return None

        location = await self._tour_api_service.get_location_by_id(location_id)
        if location is None:
            return None

        course = await self._course_generator_service.generate_course(location, season)
        return await self._enrich_course(course) if course is not None else None

    async def _enrich_course(self, course: CourseResponse) -> CourseResponse:
        """정류지 이름들로 동시에 TourAPI를 검색해(지연시간 = 가장 느린 정류지 하나만큼)
        사진·좌표를 보강한다.

        - 좌표: 이미 알고 있으면(좌표 기반 코스 생성 결과) 덮어쓰지 않고, 없는
          정류지만 채운다 (예: "저전동 골목"은 등록 관광지가 아니라 못 찾음).
        - 대표 사진: 원래 정류지 순서상 가장 앞선, 검색에 걸린 정류지의 사진을 쓴다.
        """
        infos = await asyncio.gather(
            *(self._tour_api_service.find_place_info(stop.name) for stop in course.stops)
        )

        enriched_stops = [
            stop
            if stop.latitude is not None or info is None
            else stop.model_copy(update={"latitude": info["latitude"], "longitude": info["longitude"]})
            for stop, info in zip(course.stops, infos, strict=True)
        ]

        image_url = course.image_url
        if image_url is None:
            image_url = next((info["image_url"] for info in infos if info and info["image_url"]), None)
        if image_url is None and course.location_id:
            location = await self._tour_api_service.get_location_by_id(course.location_id)
            if location is not None:
                image_url = await self._tour_api_service.get_city_image(location.region)

        return course.model_copy(update={"stops": enriched_stops, "image_url": image_url})
