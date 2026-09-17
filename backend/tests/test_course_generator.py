import pytest

from app.models.location import LocationResponse
from app.services.course_generator import CourseGeneratorService, _extract_json

_REAL_GENERATE = CourseGeneratorService._generate


def _location(**overrides) -> LocationResponse:
    base = dict(
        id="tour-999", name="테스트 동네", region="테스트시 테스트구",
        description="d", past_year=2026, current_year=2026, source="tourapi",
    )
    base.update(overrides)
    return LocationResponse(**base)


def _candidate(title: str, **overrides) -> dict:
    base = {
        "title": title, "category": "관광지", "distance_m": 300, "addr": "어딘가",
        "latitude": 37.1, "longitude": 127.1, "image_url": None,
    }
    base.update(overrides)
    return base


@pytest.mark.asyncio
async def test_generate_course_returns_none_without_coordinates() -> None:
    service = CourseGeneratorService()
    result = await service.generate_course(_location(), "가을")
    assert result is None


@pytest.mark.asyncio
async def test_candidate_pool_requires_photo_gallery_match() -> None:
    """핵심 요구사항: 관광사진 API에 사진이 없는 장소는 애초에 후보 풀에 없어야 한다."""
    class Photo:
        async def search_photos(self, keyword, num_rows=30):
            return []  # 이 지역엔 관광사진 API 결과가 없음

    service = CourseGeneratorService(photo_gallery_service=Photo())
    candidates = await service._build_photo_backed_candidates(
        _location(latitude=37.1, longitude=127.1)
    )
    assert candidates == []


@pytest.mark.asyncio
async def test_candidate_pool_drops_photos_that_do_not_match_tour_info() -> None:
    """사진은 있지만 국문 관광정보 API와 매칭 안 되는(좌표를 못 구한) 장소는 제외."""
    class Photo:
        async def search_photos(self, keyword, num_rows=30):
            return [{"title": "매칭안됨", "image_url": "https://img/x.jpg", "location_text": ""}]

    class Tour:
        async def match_tour_info(self, name, region=""):
            return None
        async def find_nearby_places(self, **kwargs):
            return []

    service = CourseGeneratorService(tour_api_service=Tour(), photo_gallery_service=Photo())
    candidates = await service._build_photo_backed_candidates(
        _location(latitude=37.1, longitude=127.1)
    )
    assert candidates == []


@pytest.mark.asyncio
async def test_candidate_pool_drops_matches_too_far_away() -> None:
    """매칭은 됐지만 위치가 너무 멀면(반경 밖) 후보에서 제외한다."""
    class Photo:
        async def search_photos(self, keyword, num_rows=30):
            return [{"title": "먼곳", "image_url": "https://img/y.jpg", "location_text": ""}]

    class Tour:
        async def match_tour_info(self, name, region=""):
            return {
                "content_id": "999", "content_type_id": "12", "name": name,
                "address": "다른 지역", "category": "관광지",
                "latitude": 30.0, "longitude": 120.0,  # 아주 먼 좌표
            }
        async def find_nearby_places(self, **kwargs):
            return []

    service = CourseGeneratorService(tour_api_service=Tour(), photo_gallery_service=Photo())
    candidates = await service._build_photo_backed_candidates(
        _location(latitude=37.1, longitude=127.1)
    )
    assert candidates == []


@pytest.mark.asyncio
async def test_candidate_pool_falls_back_to_google_places_when_photo_gallery_is_thin() -> None:
    """관광사진 API 후보가 2곳 미만이면 구글 플레이스 Nearby Search로 보강한다."""
    class Photo:
        async def search_photos(self, keyword, num_rows=30):
            return []  # 관광사진 API에 이 지역 결과가 없음

    class GooglePlaces:
        async def find_nearby(self, *, latitude, longitude, radius_m):
            return [
                {"title": "구글로 찾은 카페", "latitude": 37.101, "longitude": 127.101,
                 "address": "근처 어딘가", "image_url": "https://img/google-cafe.jpg"},
                {"title": "구글로 찾은 공원", "latitude": 37.102, "longitude": 127.102,
                 "address": "근처 어딘가2", "image_url": "https://img/google-park.jpg"},
            ]

    service = CourseGeneratorService(photo_gallery_service=Photo(), google_places_service=GooglePlaces())
    candidates = await service._build_photo_backed_candidates(
        _location(latitude=37.1, longitude=127.1)
    )
    assert {c["title"] for c in candidates} == {"구글로 찾은 카페", "구글로 찾은 공원"}
    assert all(c["image_url"] for c in candidates)
    assert all(c["content_id"] is None for c in candidates)


@pytest.mark.asyncio
async def test_candidate_pool_falls_back_to_tourapi_nearby_when_photo_gallery_and_google_are_both_thin() -> None:
    """관광사진 API도 구글 플레이스도 도움이 안 되는 동네(실측: 청명역 인근 —
    관광사진 API 0건, 구글 Nearby Search 상위는 터널·매장뿐)는 TourAPI 좌표
    검색(locationBasedList2)으로 마지막 채운다."""
    class Photo:
        async def search_photos(self, keyword, num_rows=30):
            return []

    class GooglePlaces:
        async def find_nearby(self, **kwargs):
            return []  # 이 동네에선 구글 인기순 상위에 걸맞는 후보가 없음

    class Tour:
        async def find_nearby_places(self, **kwargs):
            return [
                {"title": "영흥숲공원", "category": "관광지", "image_url": None,
                 "distance_m": 800, "addr": "경기 수원시", "latitude": 37.26, "longitude": 127.08},
                {"title": "반달공원", "category": "관광지", "image_url": "https://img/bandal.jpg",
                 "distance_m": 900, "addr": "경기 수원시", "latitude": 37.261, "longitude": 127.081},
                {"title": "청명역한빛공인중개사", "category": "관광지", "image_url": None,
                 "distance_m": 100, "addr": "경기 수원시", "latitude": 37.2601, "longitude": 127.0788},
            ]

    service = CourseGeneratorService(
        tour_api_service=Tour(), photo_gallery_service=Photo(), google_places_service=GooglePlaces()
    )
    candidates = await service._build_photo_backed_candidates(
        _location(latitude=37.2595, longitude=127.0789)
    )
    titles = {c["title"] for c in candidates}
    assert titles == {"영흥숲공원", "반달공원"}
    assert "청명역한빛공인중개사" not in titles  # 상호명 블랙리스트(공인중개사)로 제외


@pytest.mark.asyncio
async def test_candidate_pool_skips_google_places_when_photo_gallery_already_has_enough() -> None:
    """관광사진 API만으로 2곳 이상 모이면 구글 플레이스는 아예 호출하지 않는다."""
    class Photo:
        async def search_photos(self, keyword, num_rows=30):
            return [
                {"title": "실제장소A", "image_url": "https://img/a.jpg", "location_text": ""},
                {"title": "실제장소B", "image_url": "https://img/b.jpg", "location_text": ""},
            ]

    class Tour:
        async def match_tour_info(self, name, region=""):
            return {
                "content_id": name, "content_type_id": "12", "name": name,
                "address": "어딘가", "category": "관광지", "latitude": 37.101, "longitude": 127.101,
            }

    class GooglePlaces:
        async def find_nearby(self, **kwargs):
            raise AssertionError("photo gallery만으로 충분하면 구글 플레이스는 호출되면 안 됨")

    service = CourseGeneratorService(
        tour_api_service=Tour(), photo_gallery_service=Photo(), google_places_service=GooglePlaces()
    )
    candidates = await service._build_photo_backed_candidates(
        _location(latitude=37.1, longitude=127.1)
    )
    assert len(candidates) == 2


@pytest.mark.asyncio
async def test_candidate_pool_keeps_photo_backed_nearby_match() -> None:
    class Photo:
        async def search_photos(self, keyword, num_rows=30):
            return [{"title": "가까운곳", "image_url": "https://img/z.jpg", "location_text": ""}]

    class Tour:
        async def match_tour_info(self, name, region=""):
            return {
                "content_id": "111", "content_type_id": "12", "name": name,
                "address": "근처 주소", "category": "관광지",
                "latitude": 37.101, "longitude": 127.101,
            }
        async def find_nearby_places(self, **kwargs):
            return []

    service = CourseGeneratorService(tour_api_service=Tour(), photo_gallery_service=Photo())
    candidates = await service._build_photo_backed_candidates(
        _location(latitude=37.1, longitude=127.1)
    )
    assert len(candidates) == 1
    assert candidates[0]["title"] == "가까운곳"
    assert candidates[0]["image_url"] == "https://img/z.jpg"
    assert candidates[0]["content_id"] == "111"


def test_parse_course_filters_hallucinated_stops() -> None:
    service = CourseGeneratorService()
    candidates = [
        _candidate("실제공원", image_url="https://img/park.jpg"),
        _candidate("실제카페", category="음식점", distance_m=500, addr="카페주소"),
    ]
    text = (
        '{"title": "가을 산책", "description": "설명", "duration_label": "약 2시간", '
        '"category": "산책", "sentiment_score": 0.8, '
        '"stops": ["실제공원", "지어낸장소", "실제카페"]}'
    )
    course = service._parse_course(text, location=_location(), season="가을", candidates=candidates)
    assert course is not None
    assert [s.name for s in course.stops] == ["실제공원", "실제카페"]
    assert course.stops[0].latitude == 37.1
    assert course.stops[0].longitude == 127.1
    # 정류지 카드가 목록에서 카테고리·주소·사진을 바로 보여줄 수 있게, 후보의
    # 정보를 그대로 넘겨받는다(예전엔 이름/좌표만 넘기고 나머지를 버렸다).
    assert course.stops[0].image_url == "https://img/park.jpg"
    assert course.stops[1].category == "음식점"
    assert course.stops[1].address == "카페주소"
    assert course.id == "llm-tour-999-가을"


def test_parse_course_returns_none_when_too_few_real_stops_survive() -> None:
    service = CourseGeneratorService()
    candidates = [_candidate("실제공원")]
    text = '{"title": "t", "description": "d", "duration_label": "약 1시간", "category": "산책", "sentiment_score": 0.5, "stops": ["실제공원", "없는곳"]}'
    course = service._parse_course(text, location=_location(), season="가을", candidates=candidates)
    assert course is None


def test_parse_course_returns_none_on_invalid_json() -> None:
    service = CourseGeneratorService()
    course = service._parse_course("이건 JSON이 아님", location=_location(), season="가을", candidates=[])
    assert course is None


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ('{"a": 1}', '{"a": 1}'),
        ('```json\n{"a": 1}\n```', '{"a": 1}'),
        ('```\n{"a": 1}\n```', '{"a": 1}'),
        ('Here is the course:\n{"a": 1}\nHope that helps!', '{"a": 1}'),
    ],
)
def test_extract_json_handles_code_fences_and_prose(raw: str, expected: str) -> None:
    assert _extract_json(raw) == expected


def test_parse_course_handles_markdown_fenced_response() -> None:
    service = CourseGeneratorService()
    candidates = [_candidate("A"), _candidate("B", distance_m=200)]
    text = (
        '```json\n{"title": "t", "description": "d", "duration_label": "약 1시간", '
        '"category": "산책", "sentiment_score": 0.5, "stops": ["A", "B"]}\n```'
    )
    course = service._parse_course(text, location=_location(), season="가을", candidates=candidates)
    assert course is not None
    assert [s.name for s in course.stops] == ["A", "B"]


def test_parse_course_clamps_out_of_range_sentiment_score() -> None:
    service = CourseGeneratorService()
    candidates = [_candidate("A"), _candidate("B", distance_m=200)]
    text = '{"title": "t", "description": "d", "duration_label": "약 1시간", "category": "산책", "sentiment_score": 1.7, "stops": ["A", "B"]}'
    course = service._parse_course(text, location=_location(), season="가을", candidates=candidates)
    assert course is not None
    assert course.sentiment_score == 1.0


@pytest.mark.asyncio
async def test_ai_request_does_not_block_other_requests(monkeypatch):
    import asyncio
    import threading
    import time
    from types import SimpleNamespace
    completed=threading.Event()
    started=threading.Event()
    class Tour:
        async def match_tour_info(self, name, region=""):
            return {
                "content_id": name, "content_type_id": "12", "name": name,
                "address": "어딘가", "category": "관광지", "latitude": 37.1, "longitude": 127.1,
            }
    class Photo:
        async def search_photos(self, keyword, num_rows=30):
            return [
                {"title": "A", "image_url": "https://img/a.jpg", "location_text": ""},
                {"title": "B", "image_url": "https://img/b.jpg", "location_text": ""},
            ]
    def create(**kwargs):
        started.set()
        time.sleep(.1)
        completed.set()
        return SimpleNamespace(content=[SimpleNamespace(type='text',text='{"title":"t","description":"d","duration_label":"1h","sentiment_score":0.5,"stops":["A","B"]}')])
    service=CourseGeneratorService(tour_api_service=Tour(), photo_gallery_service=Photo())
    monkeypatch.setattr(service,'_get_client',lambda: SimpleNamespace(messages=SimpleNamespace(create=create)))
    async def health_check():
        for _ in range(100):
            if started.is_set(): break
            await asyncio.sleep(.001)
        assert started.is_set()
        assert not completed.is_set(), 'AI I/O blocked the event loop'
    course, _=await asyncio.gather(_REAL_GENERATE(service,_location(latitude=37.1,longitude=127.1),'가을'),health_check())
    assert course is not None
