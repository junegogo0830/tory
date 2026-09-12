from fastapi import APIRouter, HTTPException

from ...models.course import CourseResponse
from ...services.recommendation import RecommendationService

router = APIRouter(prefix="/api/course", tags=["course"])
_recommendation_service = RecommendationService()


@router.get("", response_model=list[CourseResponse])
async def get_all_courses() -> list[CourseResponse]:
    return await _recommendation_service.get_all_courses()


@router.get("/detail/{course_id}", response_model=CourseResponse)
async def get_course_detail(course_id: str) -> CourseResponse:
    course = await _recommendation_service.get_course_by_id(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course not found")
    return course


@router.get("/by-location/{location_id}", response_model=list[CourseResponse])
async def get_courses_by_location(location_id: str) -> list[CourseResponse]:
    """감성점수 결합 추천 코스. 데이터가 없으면 빈 리스트를 반환한다."""
    return await _recommendation_service.get_courses_by_location(location_id)


@router.get("/nearby", response_model=CourseResponse | None)
async def get_course_by_coords(lat: float, lng: float) -> CourseResponse | None:
    """"현재 위치" 기반 코스. 등록된 장소가 아니어도 좌표만으로 생성한다.
    주변 후보가 부족하면(콜드스팟 등) null."""
    return await _recommendation_service.get_course_by_coords(lat, lng)
