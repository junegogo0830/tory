import pytest

from app.db import redis as redis_module
from app.services.archive import ArchiveService
from app.services.kakao_local import KakaoLocalService
from app.services.tourapi import TourApiService


@pytest.fixture(autouse=True)
def _clear_local_cache(monkeypatch) -> None:
    """cache_get/cache_set의 프로세스 내 폴백 캐시는 모듈 전역이라, 테스트마다
    비워두지 않으면 한 테스트가 심어둔 값을 다른 테스트가 몰래 재사용하게 된다."""
    redis_module._local_cache.clear()
    # Never read or poison the running application's Redis during tests.
    def unavailable():
        raise ConnectionError('Use per-test in-memory cache')
    monkeypatch.setattr(redis_module, 'get_redis', unavailable)


@pytest.fixture(autouse=True)
def _no_live_tourapi_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """유닛 테스트는 외부 TourAPI 네트워크 호출에 의존하지 않는다.

    실제 TourAPI 연동 자체는 개발 중 수동으로 검증했다 — 여기서는 이미지 보강
    로직이 서비스 키 유무와 무관하게 정상적으로 None을 반환/무시하는지만 본다.
    """

    async def _no_place_info(self: TourApiService, keyword: str) -> dict | None:  # noqa: ARG001
        return None

    # find_image_url()과 _enrich_course()의 find_place_info() 호출 둘 다 결국
    # 이 메서드로 귀결되므로, 가장 아래 지점 하나만 막으면 둘 다 커버된다.
    monkeypatch.setattr(TourApiService, "_search_first_place", _no_place_info)


@pytest.fixture(autouse=True)
def _no_live_tourapi_search_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """큐레이션 3곳에 안 걸리는 검색어의 TourAPI 실시간 검색도 유닛 테스트에서는 막는다."""

    async def _no_results(self: TourApiService, query: str, num_rows: int, *, content_type_id: str = "12"):  # noqa: ARG001, ANN202
        return []

    monkeypatch.setattr(TourApiService, "_search_from_tourapi", _no_results)


@pytest.fixture(autouse=True)
def _no_live_tourapi_detail_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """`tour-*` id 상세 재조회(detailCommon2)도 유닛 테스트에서는 네트워크를 타지 않는다."""

    async def _no_detail(self: TourApiService, location_id: str):  # noqa: ARG001, ANN202
        return None

    monkeypatch.setattr(TourApiService, "_get_tourapi_detail", _no_detail)


@pytest.fixture(autouse=True)
def _no_live_naver_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """유닛 테스트는 외부 네이버 뉴스 네트워크 호출에 의존하지 않는다.

    실제 연동 자체는 개발 중 수동으로 검증했다 — 여기서는 검색 결과가 없을 때
    큐레이션 목 데이터로 정상 폴백하는지만 본다.
    """

    async def _no_results(self: ArchiveService, query: str) -> list:  # noqa: ARG001
        return []

    monkeypatch.setattr(ArchiveService, "_fetch_from_naver", _no_results)


@pytest.fixture(autouse=True)
def _no_live_kakao_local_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """유닛 테스트는 외부 카카오 로컬 API 네트워크 호출에 의존하지 않는다.

    개별 테스트가 성공 경로를 확인하고 싶으면 이 fixture 이후에
    `monkeypatch.setattr(KakaoLocalService, "geocode", ...)`로 다시 덮어쓰면 된다.
    """

    async def _no_coords(self: KakaoLocalService, query: str) -> tuple[float, float] | None:  # noqa: ARG001
        return None

    monkeypatch.setattr(KakaoLocalService, "geocode", _no_coords)


@pytest.fixture(autouse=True)
def _no_live_kakao_reverse_geocode_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """커뮤니티 "내 동네" 자동 설정용 역지오코딩도 유닛 테스트에서는 네트워크를 타지 않는다."""

    async def _no_region(self: KakaoLocalService, latitude: float, longitude: float) -> str | None:  # noqa: ARG001
        return None

    monkeypatch.setattr(KakaoLocalService, "reverse_geocode", _no_region)


@pytest.fixture(autouse=True)
def _no_live_kakao_search_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """장소 검색(search_locations/resolve_location)의 주 경로가 된 카카오 로컬
    키워드/주소 검색도 유닛 테스트에서는 네트워크를 타지 않는다."""

    async def _no_places(self: KakaoLocalService, query: str, limit: int = 5):  # noqa: ARG001
        return []

    monkeypatch.setattr(KakaoLocalService, "search_places", _no_places)


@pytest.fixture(autouse=True)
def _no_live_tourapi_nearby_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """코스 생성용 좌표 기반 주변 검색도 유닛 테스트에서는 네트워크를 타지 않는다."""

    async def _no_nearby(self: TourApiService, **kwargs) -> list[dict]:  # noqa: ARG001
        return []

    monkeypatch.setattr(TourApiService, "find_nearby_places", _no_nearby)


@pytest.fixture(autouse=True)
def _no_live_kakao_restaurant_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """카카오맵 기반 맛집 카드(전국/내 주변)도 유닛 테스트에서는 네트워크를 타지 않는다."""

    async def _no_restaurants(self: KakaoLocalService, **kwargs) -> list:  # noqa: ARG001
        return []

    monkeypatch.setattr(KakaoLocalService, "search_restaurants", _no_restaurants)


@pytest.fixture(autouse=True)
def _no_live_anthropic_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """유닛 테스트는 실제 Claude API 호출(과금 발생)에 의존하지 않는다.

    개별 테스트가 생성 성공 경로를 확인하고 싶으면 이 fixture 이후에
    `monkeypatch.setattr(CourseGeneratorService, "_generate", ...)`로 덮어쓰면 된다.
    """
    from app.services.course_generator import CourseGeneratorService

    async def _no_course(self: CourseGeneratorService, location, season):  # noqa: ARG001, ANN001
        return None

    monkeypatch.setattr(CourseGeneratorService, "_generate", _no_course)


@pytest.fixture(autouse=True)
def _no_live_anthropic_story_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """그 시절 이야기(웹 검색 기반)도 유닛 테스트에서는 실제 Claude 호출을 하지 않는다."""

    async def _no_story(self: ArchiveService, query: str):  # noqa: ARG001
        return None

    monkeypatch.setattr(ArchiveService, "_generate_story", _no_story)


@pytest.fixture(autouse=True)
def _no_live_weather_calls(monkeypatch: pytest.MonkeyPatch) -> None:
    """유닛 테스트는 실제 OpenWeatherMap 호출에 의존하지 않는다."""
    from app.services.weather import WeatherService

    async def _no_weather(self: WeatherService, latitude: float, longitude: float):  # noqa: ARG001
        return None

    monkeypatch.setattr(WeatherService, "_fetch", _no_weather)
