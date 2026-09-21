from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

import asyncio
from ...db.models import User
from ...db.postgres import get_db_session
from ...models.course import (
    CourseResponse,
    CourseGenerateRequest,
    InsertMealsRequest,
    MealCandidateRequest,
    RestaurantCandidateResponse,
)
from ...services.course_planner import CoursePlanner
from ...services.meal_planner import MealPlannerService
from ...services.profile import ProfileService
from ...services.recommendation import RecommendationService
from ..deps import get_optional_user

router = APIRouter(prefix="/api/course", tags=["course"])
_recommendation_service = RecommendationService()
_planner = CoursePlanner()
_profile_service = ProfileService()
_meal_planner_service = MealPlannerService()


@router.post('/generate', response_model=CourseResponse)
async def generate_course(
    body: CourseGenerateRequest,
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db_session),
) -> CourseResponse:
    try:
        course = await asyncio.wait_for(_planner.generate(body), timeout=18)
    except TimeoutError:
        raise HTTPException(504, '지역 정보를 가져오는 데 시간이 걸려요. 잠시 후 다시 시도해주세요') from None
    # 로그인 상태면 "내가 만든 코스"에 자동으로 영구 저장한다 — 별도 저장 버튼 없이
    # 프로필 탭에서 바로 다시 볼 수 있게.
    if user is not None:
        await _profile_service.save_generated_course(db, user, course)
    return course


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


@router.post("/meal-candidates", response_model=dict[str, list[RestaurantCandidateResponse]])
async def meal_candidates(body: MealCandidateRequest) -> dict[str, list[RestaurantCandidateResponse]]:
    """이미 만들어진 관광 코스에 식사를 추가하기 전 단계 — 식사 시간대별로 실제
    음식점 후보를 검색하고 Claude가 순위만 매긴다(최종 선택은 사용자 몫)."""
    return await _meal_planner_service.find_candidates(
        body.course,
        meal_types=body.meal_types,
        food_categories=body.food_categories,
        price_range=body.price_range,
        age_group=body.age_group,
    )


@router.post("/meals", response_model=CourseResponse)
async def insert_meals(body: InsertMealsRequest) -> CourseResponse:
    """사용자가 식사별로 고른 식당을 코스에 반영 — 새 장소를 추천하지 않고
    좌표 기반으로 삽입 위치만 재계산한다. 같은 요청을 다른 식당으로 다시
    보내면 "변경"이 되고, meals를 비운 채(기존 식사 없이) 보내면 "삭제"가 된다."""
    return _meal_planner_service.insert_meals(body.course, body.meals)
