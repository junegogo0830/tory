from typing import Literal
from pydantic import BaseModel, Field

CourseCategory = Literal['산책', '역사', '미식', '문화', '자연', '가족']
MealType = Literal['breakfast', 'lunch', 'dinner']
PriceRange = Literal['가성비', '보통', '여유롭게', '상관없음']
MealAgeGroup = Literal['10대', '20대', '30대', '40대', '50대', '60대 이상', '상관없음']


class CourseGenerateRequest(BaseModel):
    region: str = Field(min_length=2, max_length=100)
    age_group: Literal['선택 안 함', '10대', '20대', '30대', '40대', '50대', '60대 이상'] = '선택 안 함'
    gender: Literal['선택 안 함', '여성', '남성', '기타'] = '선택 안 함'
    categories: list[CourseCategory] = Field(default_factory=lambda: ['산책'], min_length=1, max_length=6)
    weather_mode: Literal['current', 'clear', 'rain', 'snow', 'hot', 'cold'] = 'current'
    pace: Literal['여유롭게', '보통', '활기차게'] = '보통'
    duration_hours: int = Field(default=3, ge=1, le=8)


class CourseStop(BaseModel):
    name: str
    source: str = ''
    # 실제 등록된 장소와 매칭됐을 때만 채워진다 — 있으면 프론트에서 카카오맵
    # 길찾기 딥링크를 만들 수 있다. 큐레이션 코스의 일부 정류지(가상의 옛길
    # 골목 등)는 등록된 장소가 아니라 None으로 남을 수 있다.
    latitude: float | None = None
    longitude: float | None = None
    category: str = ''
    address: str = ''
    stay_minutes: int = 30
    # TourApiService.find_place_info로 보강된 정류지 사진 — 없으면 프론트가
    # 자체 폴백 아이콘을 보여준다.
    image_url: str | None = None
    # image_url이 구글 플레이스 사진일 때만 채워진다 — 구글 이용약관상 사진을
    # 보여주려면 기여자 출처 표기를 같이 보여줘야 한다.
    photo_attribution_name: str | None = None
    photo_attribution_url: str | None = None
    # 식사 추가 플로우로 삽입된 정류지인지 — 프론트가 "변경"/"삭제" 액션을
    # 보여줄지 판단한다. 처음 생성된 관광 코스의 정류지는 항상 False.
    is_meal: bool = False
    meal_type: MealType | None = None


class CourseResponse(BaseModel):
    id: str
    title: str
    description: str
    sentiment_score: float
    stops: list[CourseStop]
    duration_label: str
    category: str
    image_url: str | None = None
    # 프론트가 "이 코스 주변 맛집" 등을 조회할 때 쓴다.
    location_id: str = ""
    region: str = ''
    weather_label: str = ''
    estimated_distance_km: float | None = None
    notes: list[str] = Field(default_factory=list)
    source: str = 'curated'


class RestaurantCandidateResponse(BaseModel):
    """식사 추가 플로우의 식당 후보 — 실제 검색 결과만 담는다(Claude가 새로
    만들어내지 않는다). restaurant_id는 화면에서 선택/삽입 요청을 보낼 때
    그대로 다시 실어 보내는 값이라, 서버가 재조회하지 않고도 검증할 수 있다."""

    restaurant_id: str
    name: str
    category: str = ''
    address: str = ''
    latitude: float | None = None
    longitude: float | None = None
    image_url: str | None = None
    photo_attribution_name: str | None = None
    photo_attribution_url: str | None = None
    # 이 식당을 넣었을 때 기존 동선에서 얼마나 더 돌아가야 하는지(m) — 작을수록 좋다.
    detour_m: int | None = None
    # Claude가 후보 순위를 매긴 이유(짧은 한 줄). 랭킹 실패 시 None.
    reason: str | None = None


class MealCandidateRequest(BaseModel):
    """이미 만들어진 코스에 식사를 추가하기 전 후보를 조회한다 — 코스는 값으로
    통째로 실어 보낸다(큐레이션/LLM/플래너 코스 아이디 체계가 서로 달라 서버가
    id만으로 다시 찾아오기 어렵고, 화면엔 이미 전체 코스가 있으니 그대로 쓴다)."""

    course: CourseResponse
    meal_types: list[MealType] = Field(min_length=1, max_length=3)
    food_categories: list[str] = Field(default_factory=list)
    price_range: PriceRange | None = None
    age_group: MealAgeGroup | None = None


class SelectedMeal(BaseModel):
    meal_type: MealType
    restaurant: RestaurantCandidateResponse


class InsertMealsRequest(BaseModel):
    """사용자가 식사별로 하나씩 고른 식당을 기존 코스에 반영한다. restaurant는
    직전 후보 조회 응답을 그대로 되돌려 보내는 값 — 서버는 이 값을 그대로
    신뢰하고(직접 검색한 real data), 삽입 위치/순서만 다시 계산한다.
    meals를 빈 리스트로 보내면 기존에 추가돼있던 식사를 전부 지운다("식사 삭제")."""

    course: CourseResponse
    meals: list[SelectedMeal] = Field(default_factory=list, max_length=3)
