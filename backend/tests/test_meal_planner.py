import pytest

from app.models.course import CourseResponse, CourseStop, RestaurantCandidateResponse, SelectedMeal
from app.services.meal_planner import MealPlannerService, _detour_phrase, _insertion_detour_m, _meal_anchor_index

# conftest.py의 autouse fixture가 MealPlannerService._fill_missing_photos 자체를
# no-op으로 막아둔다(다른 테스트가 실제 구글 호출에 의존하지 않게) — 그 로직을
# 직접 검증하는 테스트는 패치되기 전 원본 구현을 모듈 임포트 시점에 미리
# 붙잡아둬야 한다.
_REAL_FILL_MISSING_PHOTOS = MealPlannerService._fill_missing_photos


def _stop(name: str, lat: float, lng: float, *, is_meal: bool = False) -> CourseStop:
    return CourseStop(name=name, latitude=lat, longitude=lng, is_meal=is_meal)


def _course(stops: list[CourseStop]) -> CourseResponse:
    return CourseResponse(
        id="llm-test-summer", title="테스트 코스", description="", sentiment_score=0.8,
        stops=stops, duration_label="약 3시간", category="산책",
    )


# 서울 시청 근처 임의의 좌표 4개(대략 동쪽으로 이동하는 동선).
A = (37.5665, 126.9780)
B = (37.5651, 126.9895)
C = (37.5636, 127.0010)
D = (37.5622, 127.0125)


def test_meal_anchor_index_picks_start_middle_end() -> None:
    assert _meal_anchor_index(4, "breakfast") == 0
    assert _meal_anchor_index(4, "lunch") == 2
    assert _meal_anchor_index(4, "dinner") == 3
    assert _meal_anchor_index(1, "dinner") == 0


def test_insertion_detour_is_zero_when_restaurant_is_on_the_route() -> None:
    prev, next_ = _stop("A", *A), _stop("B", *B)
    # prev/next와 정확히 같은 좌표면(사실상 그 자리) 우회가 거의 없어야 한다.
    detour = _insertion_detour_m(prev, next_, *A)
    assert detour == 0


def test_insertion_detour_grows_with_distance_from_route() -> None:
    prev, next_ = _stop("A", *A), _stop("B", *B)
    near = _insertion_detour_m(prev, next_, 37.566, 126.984)
    far = _insertion_detour_m(prev, next_, 37.9, 127.5)  # 전혀 다른 동네
    assert 0 <= near < far


@pytest.mark.asyncio
async def test_find_candidates_filters_sorts_and_dedupes(monkeypatch: pytest.MonkeyPatch) -> None:
    service = MealPlannerService()
    course = _course([_stop("A", *A), _stop("B", *B), _stop("C", *C)])

    async def _fake_retrieve(self, latitude, longitude, food_categories):  # noqa: ARG001, ANN001
        return [
            {"id": "near", "name": "근처식당", "category": "한식", "address": "", "latitude": B[0], "longitude": B[1], "image_url": None},
            {"id": "far", "name": "먼식당", "category": "한식", "address": "", "latitude": 37.9, "longitude": 127.5, "image_url": None},
            {"id": "dup", "name": "근처식당", "category": "한식", "address": "", "latitude": B[0], "longitude": B[1], "image_url": None},
            {"id": "wrong-category", "name": "일식당", "category": "일식", "address": "", "latitude": B[0], "longitude": B[1], "image_url": None},
        ]

    monkeypatch.setattr(MealPlannerService, "_retrieve_restaurants", _fake_retrieve)

    results = await service.find_candidates(
        course, meal_types=["lunch"], food_categories=["한식"], price_range=None, age_group=None,
    )

    lunch = results["lunch"]
    names = [c.name for c in lunch]
    assert names.count("근처식당") == 1  # 중복 제거
    assert "일식당" not in names  # 카테고리 필터
    assert lunch[0].name == "근처식당"  # detour 오름차순 정렬
    assert lunch[0].detour_m is not None and lunch[0].detour_m < lunch[-1].detour_m


def test_detour_phrase_never_leaks_english_jargon_or_raw_numbers() -> None:
    for meters in (0, 199, 500, 999, 5000):
        phrase = _detour_phrase(meters)
        assert "detour" not in phrase.lower()
        assert "m" not in phrase or "동선" in phrase  # 숫자+단위(예: "398m")가 아니라 자연어 문구인지
        assert any(ch.isdigit() for ch in phrase) is False


@pytest.mark.asyncio
async def test_fill_missing_photos_backfills_only_candidates_without_image(monkeypatch: pytest.MonkeyPatch) -> None:
    service = MealPlannerService()
    has_photo = RestaurantCandidateResponse(restaurant_id="a", name="사진있음", image_url="https://already.jpg")
    no_photo = RestaurantCandidateResponse(restaurant_id="b", name="사진없음")
    pools = {"lunch": [has_photo, no_photo]}

    calls: list[str] = []

    async def _fake_find_photo(self, name, region):  # noqa: ARG001, ANN001
        calls.append(name)
        return {"image_url": "https://google.jpg", "attribution_name": "누군가", "attribution_url": "https://x"}

    monkeypatch.setattr(type(service._google_places_service), "find_photo", _fake_find_photo)

    await _REAL_FILL_MISSING_PHOTOS(service, pools, "서울")

    assert calls == ["사진없음"]  # 이미 사진 있는 후보는 호출하지 않는다.
    assert pools["lunch"][0].image_url == "https://already.jpg"  # 그대로 유지
    assert pools["lunch"][1].image_url == "https://google.jpg"
    assert pools["lunch"][1].photo_attribution_name == "누군가"


@pytest.mark.asyncio
async def test_find_candidates_returns_empty_without_coordinates() -> None:
    service = MealPlannerService()
    course = _course([CourseStop(name="좌표 없는 정류지")])
    results = await service.find_candidates(
        course, meal_types=["lunch", "dinner"], food_categories=[], price_range=None, age_group=None,
    )
    assert results == {"lunch": [], "dinner": []}


def _restaurant(name: str, lat: float, lng: float) -> RestaurantCandidateResponse:
    return RestaurantCandidateResponse(restaurant_id=name, name=name, latitude=lat, longitude=lng)


def test_insert_meals_places_restaurant_at_lowest_detour_position() -> None:
    service = MealPlannerService()
    course = _course([_stop("A", *A), _stop("B", *B), _stop("C", *C), _stop("D", *D)])
    # B 바로 근처 좌표 -> A와 B 사이(또는 B와 C 사이)에 들어가야지, 맨 끝(D 뒤)에 붙으면 안 된다.
    restaurant = _restaurant("점심식당", 37.5648, 126.990)

    updated = service.insert_meals(course, [SelectedMeal(meal_type="lunch", restaurant=restaurant)])

    names = [s.name for s in updated.stops]
    assert "점심식당" in names
    idx = names.index("점심식당")
    assert 0 < idx < len(names) - 1  # 맨 앞/뒤가 아니라 중간 어딘가에 자연스럽게 삽입
    inserted_stop = updated.stops[idx]
    assert inserted_stop.is_meal is True
    assert inserted_stop.meal_type == "lunch"
    assert inserted_stop.stay_minutes == 60


def test_insert_meals_replaces_previous_meal_selection() -> None:
    service = MealPlannerService()
    course = _course([_stop("A", *A), _stop("아침식당", *B, is_meal=True), _stop("C", *C)])
    new_breakfast = _restaurant("다른아침식당", *B)

    updated = service.insert_meals(course, [SelectedMeal(meal_type="breakfast", restaurant=new_breakfast)])

    names = [s.name for s in updated.stops]
    assert "아침식당" not in names
    assert "다른아침식당" in names
    assert sum(1 for s in updated.stops if s.is_meal) == 1


def test_insert_meals_with_empty_list_removes_all_meals() -> None:
    service = MealPlannerService()
    course = _course([_stop("A", *A), _stop("점심식당", *B, is_meal=True), _stop("C", *C)])

    updated = service.insert_meals(course, [])

    assert all(not s.is_meal for s in updated.stops)
    assert [s.name for s in updated.stops] == ["A", "C"]


def test_insert_meals_recomputes_estimated_distance() -> None:
    service = MealPlannerService()
    course = _course([_stop("A", *A), _stop("D", *D)])
    restaurant = _restaurant("중간식당", *B)

    updated = service.insert_meals(course, [SelectedMeal(meal_type="lunch", restaurant=restaurant)])

    assert updated.estimated_distance_km is not None
    assert updated.estimated_distance_km > 0
