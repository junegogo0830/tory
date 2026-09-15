import pytest

from app.models.course import CourseResponse, CourseStop
from app.services.recommendation import RecommendationService
from app.services.tourapi import TourApiService


@pytest.mark.asyncio
async def test_enrich_course_fills_each_stop_image_url(monkeypatch: pytest.MonkeyPatch) -> None:
    """큐레이션 코스의 정류지는 이름만 있고 사진이 없다 — 코스 상세를 "로드맵"
    형태로 보여주려면 정류지별 사진이 있어야 한다. _enrich_course가 TourAPI
    검색 결과의 image_url을 각 정류지에 채워 넣는지 확인한다(예전엔 코스
    대표 사진 하나에만 쓰고 정류지별로는 버렸다)."""

    async def fake_place_info(self: TourApiService, keyword: str) -> dict | None:
        images = {"저전동 골목": "https://img/jeonpo.jpg", "순천만국가정원": "https://img/garden.jpg"}
        if keyword not in images:
            return None
        return {"image_url": images[keyword], "latitude": 34.9, "longitude": 127.5}

    monkeypatch.setattr(TourApiService, "find_place_info", fake_place_info)

    service = RecommendationService()
    course = CourseResponse(
        id="test-course",
        title="테스트 코스",
        description="설명",
        sentiment_score=0.5,
        stops=[
            CourseStop(name="저전동 골목"),
            CourseStop(name="순천만국가정원"),
            CourseStop(name="없는 곳"),
        ],
        duration_label="약 2시간",
        category="산책",
    )

    result = await service._enrich_course(course)

    assert result.stops[0].image_url == "https://img/jeonpo.jpg"
    assert result.stops[0].latitude == 34.9
    assert result.stops[1].image_url == "https://img/garden.jpg"
    assert result.stops[2].image_url is None
    # 좌표가 이미 있던 정류지는 검색 결과로 덮어쓰지 않는다(기존 동작 유지).
    course2 = CourseResponse(
        id="test-course-2",
        title="테스트 코스2",
        description="설명",
        sentiment_score=0.5,
        stops=[CourseStop(name="저전동 골목", latitude=1.0, longitude=2.0)],
        duration_label="약 2시간",
        category="산책",
    )
    result2 = await service._enrich_course(course2)
    assert result2.stops[0].latitude == 1.0
    assert result2.stops[0].longitude == 2.0
    assert result2.stops[0].image_url == "https://img/jeonpo.jpg"
