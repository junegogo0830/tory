import pytest

from app.models.location import LocationResponse
from app.services.course_generator import CourseGeneratorService, _extract_json


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
        "latitude": 37.1, "longitude": 127.1,
    }
    base.update(overrides)
    return base


@pytest.mark.asyncio
async def test_generate_course_returns_none_without_coordinates() -> None:
    service = CourseGeneratorService()
    result = await service.generate_course(_location(), "가을")
    assert result is None


def test_parse_course_filters_hallucinated_stops() -> None:
    service = CourseGeneratorService()
    candidates = [_candidate("실제공원"), _candidate("실제카페", category="음식점", distance_m=500)]
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
