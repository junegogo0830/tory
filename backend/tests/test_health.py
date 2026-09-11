from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_location_stub_returns_mock_when_no_api_key() -> None:
    response = client.get("/api/location", params={"query": "전라남도 순천시"})
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == "suncheon-jeonpo"
    assert body["source"] == "mock"


def test_archive_returns_empty_list_for_cold_spot() -> None:
    response = client.get("/api/archive/yeongwol-jang")
    assert response.status_code == 200
    assert response.json() == []


def test_archive_falls_back_to_curated_mock_when_naver_has_no_results() -> None:
    # conftest가 네이버 검색 결과를 항상 []로 만들므로, 큐레이션 목 데이터로 폴백해야 한다.
    response = client.get("/api/archive/suncheon-jeonpo")
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 3
    assert body[0]["year"] == 1998


def test_region_story_is_null_when_location_not_found() -> None:
    response = client.get("/api/archive/tour-does-not-exist/story")
    assert response.status_code == 200
    assert response.json() is None


def test_region_story_is_null_when_claude_finds_nothing() -> None:
    # conftest가 _generate_story를 항상 None으로 만든다(과금 방지).
    response = client.get("/api/archive/suncheon-jeonpo/story")
    assert response.status_code == 200
    assert response.json() is None


def test_region_story_returns_generated_summary(monkeypatch) -> None:
    from app.models.news import RegionStoryResponse
    from app.services.archive import ArchiveService

    async def _fake_story(self: ArchiveService, query: str) -> RegionStoryResponse:  # noqa: ARG001
        return RegionStoryResponse(summary="1998년 저전동에는 골목시장이 있었다. (출처: 순천신문)")

    monkeypatch.setattr(ArchiveService, "_generate_story", _fake_story)

    response = client.get("/api/archive/suncheon-jeonpo/story")
    assert response.status_code == 200
    body = response.json()
    assert "저전동" in body["summary"]


def test_region_story_is_cached_after_first_call(monkeypatch) -> None:
    from app.models.news import RegionStoryResponse
    from app.services.archive import ArchiveService

    calls = 0

    async def _fake_story(self: ArchiveService, query: str) -> RegionStoryResponse:  # noqa: ARG001
        nonlocal calls
        calls += 1
        return RegionStoryResponse(summary="한 번만 생성돼야 하는 이야기")

    monkeypatch.setattr(ArchiveService, "_generate_story", _fake_story)

    first = client.get("/api/archive/gunsan-jungang/story")
    second = client.get("/api/archive/gunsan-jungang/story")
    assert first.status_code == second.status_code == 200
    assert first.json() == second.json()
    assert calls == 1


def test_strip_html_removes_tags_and_unescapes_entities() -> None:
    from app.core.text import strip_html

    assert strip_html("<b>순천</b> &quot;전포동&quot; 소식") == '순천 "전포동" 소식'


def test_nearby_restaurants_empty_when_location_not_found() -> None:
    response = client.get("/api/location/tour-does-not-exist/nearby-restaurants")
    assert response.status_code == 200
    assert response.json() == []


def test_nearby_restaurants_returns_real_places(monkeypatch) -> None:
    from app.models.location import LocationResponse
    from app.services.tourapi import TourApiService

    async def _fake_get_location(self: TourApiService, location_id: str) -> LocationResponse:  # noqa: ARG001
        return LocationResponse(
            id="tour-777", name="영통 아파트단지", region="경기도 수원시 영통구",
            description="d", past_year=2026, current_year=2026, source="tourapi",
            latitude=37.26, longitude=127.05,
        )

    async def _fake_nearby(self: TourApiService, **kwargs) -> list[dict]:  # noqa: ARG001
        return [
            {"title": "노대감감자탕", "category": "음식점", "distance_m": 483, "addr": "어딘가",
             "latitude": 37.261, "longitude": 127.051},
        ]

    monkeypatch.setattr(TourApiService, "get_location_by_id", _fake_get_location)
    monkeypatch.setattr(TourApiService, "find_nearby_places", _fake_nearby)

    response = client.get("/api/location/tour-777/nearby-restaurants")
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["name"] == "노대감감자탕"
    assert body[0]["distance_m"] == 483


def test_location_all_returns_seed_locations() -> None:
    response = client.get("/api/location/all")
    assert response.status_code == 200
    ids = {item["id"] for item in response.json()}
    assert ids == {"suncheon-jeonpo", "gunsan-jungang", "yeongwol-jang"}


def test_courses_by_location_empty_for_unknown_non_curated_location() -> None:
    # conftest가 TourAPI 상세 조회를 항상 None으로 만드므로, 큐레이션 밖의
    # 존재하지 않는 id는 빈 리스트여야 한다(예전처럼 엉뚱한 코스가 나오면 안 됨).
    response = client.get("/api/course/by-location/tour-does-not-exist")
    assert response.status_code == 200
    assert response.json() == []


def test_courses_by_location_uses_generated_course_for_non_curated_location(monkeypatch) -> None:
    from app.models.course import CourseResponse, CourseStop
    from app.models.location import LocationResponse
    from app.services.course_generator import CourseGeneratorService
    from app.services.tourapi import TourApiService

    async def _fake_get_location(self: TourApiService, location_id: str) -> LocationResponse:  # noqa: ARG001
        return LocationResponse(
            id="tour-777", name="영통 아파트단지", region="경기도 수원시 영통구",
            description="d", past_year=2026, current_year=2026, source="tourapi",
            latitude=37.26, longitude=127.05,
        )

    async def _fake_generate(self: CourseGeneratorService, location, season):  # noqa: ARG001, ANN001
        return CourseResponse(
            id=f"llm-{location.id}-{season}", title="가을 동네 산책",
            description="설명", sentiment_score=0.7,
            stops=[
                CourseStop(name="매탄공원", latitude=37.27, longitude=127.05),
                CourseStop(name="수원야외음악당", latitude=37.26, longitude=127.03),
            ],
            duration_label="약 1시간 30분", category="산책",
        )

    monkeypatch.setattr(TourApiService, "get_location_by_id", _fake_get_location)
    monkeypatch.setattr(CourseGeneratorService, "generate_course", _fake_generate)

    response = client.get("/api/course/by-location/tour-777")
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["id"].startswith("llm-tour-777-")
    assert [s["name"] for s in body[0]["stops"]] == ["매탄공원", "수원야외음악당"]
    assert body[0]["stops"][0]["latitude"] == 37.27


def test_course_includes_category() -> None:
    response = client.get("/api/course/detail/c1")
    assert response.status_code == 200
    assert response.json()["category"] == "산책"


def test_location_has_image_url_field() -> None:
    # conftest가 TourAPI 이미지 조회를 막아두므로 None이어야 하지만,
    # 필드 자체는 응답 스키마에 항상 존재해야 한다.
    response = client.get("/api/location/suncheon-jeonpo")
    assert response.status_code == 200
    assert "image_url" in response.json()


def test_course_has_image_url_field() -> None:
    response = client.get("/api/course/detail/c1")
    assert response.status_code == 200
    assert "image_url" in response.json()


def test_profile_requires_auth() -> None:
    response = client.get("/api/profile")
    assert response.status_code == 401


def test_resolve_location_404s_when_nothing_matches() -> None:
    # conftest가 TourAPI 실시간 검색도 항상 None으로 만들므로, 큐레이션 3곳 밖의
    # 검색어는 예전처럼 순천으로 조용히 대체되지 않고 404여야 한다.
    response = client.get("/api/location", params={"query": "존재하지않는아무말 12345"})
    assert response.status_code == 404


def test_get_location_by_tourapi_id_uses_detail_lookup(monkeypatch) -> None:
    from app.models.location import LocationResponse
    from app.services.tourapi import TourApiService

    async def _fake_detail(self: TourApiService, location_id: str) -> LocationResponse:  # noqa: ARG001
        return LocationResponse(
            id=location_id, name="해운대 관광특구", region="부산광역시 해운대구",
            description="실제 소개 문구", past_year=2026, current_year=2026, source="tourapi",
        )

    monkeypatch.setattr(TourApiService, "_get_tourapi_detail", _fake_detail)

    response = client.get("/api/location/tour-127004")
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "해운대 관광특구"
    assert body["description"] == "실제 소개 문구"


def test_get_location_by_tourapi_id_404s_when_detail_lookup_fails() -> None:
    # conftest가 _get_tourapi_detail을 항상 None으로 만들어둔다.
    response = client.get("/api/location/tour-does-not-exist")
    assert response.status_code == 404


def test_search_locations_returns_curated_match_plus_empty_kakao_results() -> None:
    # conftest가 카카오 검색을 항상 []로 만들므로, 큐레이션 매칭만 나와야 한다.
    response = client.get("/api/location/search", params={"query": "전라남도 순천시 저전동", "limit": 5})
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["id"] == "suncheon-jeonpo"


def test_search_locations_returns_empty_list_when_nothing_matches() -> None:
    response = client.get("/api/location/search", params={"query": "존재하지않는아무말 12345"})
    assert response.status_code == 200
    assert response.json() == []


def test_search_locations_uses_live_kakao_results(monkeypatch) -> None:
    from app.services.kakao_local import KakaoLocalService

    async def _fake_search(self: KakaoLocalService, query: str, limit: int = 5) -> list[dict]:  # noqa: ARG001
        return [
            {"id": "111", "name": "해운대 해수욕장", "address": "부산광역시 해운대구",
             "latitude": 35.16, "longitude": 129.16},
            {"id": "", "name": "해운대 시장", "address": "부산광역시 해운대구",
             "latitude": 35.17, "longitude": 129.17},
        ]

    monkeypatch.setattr(KakaoLocalService, "search_places", _fake_search)

    response = client.get("/api/location/search", params={"query": "해운대", "limit": 5})
    assert response.status_code == 200
    body = response.json()
    assert body[0]["id"] == "kakao-111"
    assert body[0]["source"] == "kakao"
    # 카카오 장소 id가 없는 결과(순수 주소 검색)는 이름+주소로 만든 안정적인 id를 쓴다.
    assert body[1]["id"].startswith("kakao-")
    assert body[1]["id"] != "kakao-"


def test_resolve_location_uses_live_kakao_result_when_available(monkeypatch) -> None:
    from app.services.kakao_local import KakaoLocalService

    async def _fake_search(self: KakaoLocalService, query: str, limit: int = 5) -> list[dict]:  # noqa: ARG001
        return [{"id": "999", "name": "부산 해운대", "address": "부산광역시 해운대구",
                  "latitude": 35.16, "longitude": 129.16}]

    monkeypatch.setattr(KakaoLocalService, "search_places", _fake_search)

    response = client.get("/api/location", params={"query": "부산 해운대"})
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == "kakao-999"
    assert body["source"] == "kakao"
    assert body["past_year"] == body["current_year"]


def test_get_location_by_kakao_id_reads_search_time_cache() -> None:
    # 카카오는 id로 재조회하는 REST 엔드포인트가 없어서, 검색 때 캐싱해둔 걸
    # get_location_by_id가 그대로 읽어야 한다. 캐시에 없는 kakao-id는 404.
    response = client.get("/api/location/kakao-never-searched")
    assert response.status_code == 404
