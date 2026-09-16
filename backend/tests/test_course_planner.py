import asyncio
from types import SimpleNamespace
import pytest
from fastapi import HTTPException
from app.models.course import CourseGenerateRequest
from app.services.course_planner import CoursePlanner, distance_km

class Tour:
    async def find_nearby_places(self, **kwargs):
        return [dict(title='테스트박물관',category='문화시설',latitude=37.501,longitude=127.001,addr='테스트시',image_url='https://tong.visitkorea.or.kr/test.jpg'),dict(title='작은전시관',category='문화시설',latitude=37.502,longitude=127.002,addr='테스트시'),dict(title='먼 공원',category='관광지',latitude=38.,longitude=128.,addr='다른시')]
class Kakao:
    async def geocode(self, region): return (37.5,127.)
    async def search_places(self, query, limit=10): return []
class Weather:
    async def get_current_weather(self,*args): return SimpleNamespace(condition='rain_day',temperature=20,description='비')

@pytest.mark.asyncio
async def test_weather_real_candidates_and_detail_cache():
    from app.db.redis import cache_get
    planner=CoursePlanner(Tour(),Kakao(),Weather())
    req=CourseGenerateRequest(region='테스트시',categories=['문화','산책'],duration_hours=3)
    result=await planner.generate(req)
    assert result.stops[0].name=='테스트박물관'
    assert all(s.source == 'tourapi' for s in result.stops)
    assert result.source == 'tourapi'
    assert '먼 공원' not in [s.name for s in result.stops]
    assert len({s.name for s in result.stops})==len(result.stops)
    assert result.weather_label=='비 · 20°C'
    assert result.estimated_distance_km < 2
    assert await cache_get('course-detail:'+result.id)

@pytest.mark.asyncio
async def test_backfills_missing_stop_photos_with_google_places():
    """TourAPI 대표사진이 없는 정류지(카카오 후보 포함)만 구글 플레이스로 보강한다."""
    class GooglePlaces:
        def __init__(self):
            self.queried = []
        async def find_photo(self, name, region=None):
            self.queried.append(name)
            return {
                'image_url': f'https://google/{name}.jpg',
                'attribution_name': '기여자',
                'attribution_url': 'https://maps.google.com/contrib/1',
            }
    google_places = GooglePlaces()
    planner = CoursePlanner(Tour(), Kakao(), Weather(), google_places)
    req = CourseGenerateRequest(region='테스트시', categories=['문화', '산책'], duration_hours=3)
    result = await planner.generate(req)
    by_name = {s.name: s for s in result.stops}
    # 테스트박물관은 Tour fixture에서 이미 TourAPI 사진이 있으니 구글 플레이스를 안 거친다.
    assert by_name['테스트박물관'].image_url == 'https://tong.visitkorea.or.kr/test.jpg'
    assert by_name['테스트박물관'].photo_attribution_name is None
    # 작은전시관은 TourAPI 사진이 없으니 구글 플레이스로 채워지고, 출처 표기도 같이 붙는다.
    assert by_name['작은전시관'].image_url == 'https://google/작은전시관.jpg'
    assert by_name['작은전시관'].photo_attribution_name == '기여자'
    assert by_name['작은전시관'].photo_attribution_url == 'https://maps.google.com/contrib/1'
    assert '작은전시관' in google_places.queried
    assert '테스트박물관' not in google_places.queried


@pytest.mark.asyncio
async def test_preferences_change_cache_identity():
    planner=CoursePlanner(Tour(),Kakao(),Weather())
    a=await planner.generate(CourseGenerateRequest(region='다른테스트시',categories=['문화','산책'],weather_mode='clear'))
    b=await planner.generate(CourseGenerateRequest(region='다른테스트시',categories=['문화','산책'],weather_mode='clear',pace='여유롭게'))
    assert a.id != b.id

@pytest.mark.asyncio
async def test_unavailable_location_does_not_invent_places():
    class Missing(Kakao):
        async def geocode(self, region): return None
    with pytest.raises(HTTPException) as error:
        await CoursePlanner(Tour(),Missing(),Weather()).generate(CourseGenerateRequest(region='없는시'))
    assert error.value.status_code==404

@pytest.mark.parametrize('data',[{'categories':[]},{'duration_hours':0},{'age_group':'invalid'},{'categories':['invalid']}])
def test_invalid_preferences(data):
    from pydantic import ValidationError
    with pytest.raises(ValidationError): CourseGenerateRequest(region='서울',**data)

def test_distance():
    assert distance_km((37,127),(37,127)) == 0
    assert 1 < distance_km((37,127),(37.01,127)) < 1.2
