"""Fast, reproducible routes using only places returned by tourism/place APIs."""
import asyncio
import hashlib
import json
import math
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from ..db.redis import cache_get, cache_set
from ..models.course import CourseGenerateRequest, CourseResponse, CourseStop
from .tourapi import TourApiService
from .kakao_local import KakaoLocalService
from .weather import WeatherService

KEYWORDS = {"산책": "공원", "역사": "유적", "미식": "음식점", "문화": "박물관", "자연": "수목원", "가족": "체험관"}


def distance_km(a, b):
    lat1, lng1, lat2, lng2 = map(math.radians, (*a, *b))
    v = math.sin((lat2-lat1)/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin((lng2-lng1)/2)**2
    return 6371 * 2 * math.asin(min(1, math.sqrt(v)))


class CoursePlanner:
    def __init__(self, tour=None, kakao=None, weather=None):
        self.tour = tour or TourApiService()
        self.kakao = kakao or KakaoLocalService()
        self.weather = weather or WeatherService()

    async def generate(self, request: CourseGenerateRequest) -> CourseResponse:
        request = request.model_copy(update={"region": request.region.strip(), "categories": list(dict.fromkeys(request.categories))})
        if len(request.region) < 2:
            raise HTTPException(422, "지역을 선택해주세요")
        # Short-lived plan cache includes every preference and the current weather time bucket.
        bucket = datetime.now(ZoneInfo("Asia/Seoul")).strftime("%Y%m%d%H")
        digest = hashlib.sha256(("v2:" + request.model_dump_json() + bucket).encode()).hexdigest()[:24]
        key = f"course-detail:plan-{digest}"
        cached = await cache_get(key)
        if cached:
            return CourseResponse.model_validate_json(cached)
        coords = await self.kakao.geocode(request.region)
        if not coords:
            raise HTTPException(404, "지역 위치를 찾지 못했어요. 시·군·구를 다시 선택해주세요")
        async def nearby():
            places = await self.tour.find_nearby_places(latitude=coords[0], longitude=coords[1], radius_m=5000, num_rows=60)
            return [dict(p, source='tourapi') for p in places]
        async def topic(category):
            found = await self.kakao.search_places(f"{request.region} {KEYWORDS[category]}", limit=10)
            return [dict(title=p['name'], addr=p['address'], latitude=p['latitude'], longitude=p['longitude'], category=category, source='kakao') for p in found]
        results = await asyncio.gather(nearby(), self.weather.get_current_weather(*coords), *(topic(c) for c in request.categories))
        candidates, weather, *topics = results
        # Topic matches are stronger than the broad TourAPI type labels.
        combined = [p for group in topics for p in group] + candidates
        unique = {}
        for p in combined:
            lat, lng = p.get('latitude'), p.get('longitude')
            if not p.get('title') or lat is None or lng is None or not (-90 <= lat <= 90 and -180 <= lng <= 180):
                continue
            if distance_km(coords, (lat, lng)) > 7:
                continue
            unique.setdefault((p['title'], round(lat, 4), round(lng, 4)), p)
        mode = request.weather_mode
        weather_label = {"clear": "맑은 날", "rain": "비 오는 날", "snow": "눈 오는 날", "hot": "더운 날", "cold": "추운 날"}.get(mode, "현재 날씨 확인 불가")
        if mode == 'current' and weather:
            weather_label = f"{weather.description} · {weather.temperature:.0f}°C"
            mode = 'rain' if weather.condition.startswith('rain') else 'snow' if weather.condition.startswith('snow') else 'hot' if weather.temperature >= 30 else 'cold' if weather.temperature <= 0 else 'clear'
        indoor = mode in ('rain', 'snow', 'hot', 'cold')
        pool = list(unique.values())
        def relevance(p):
            category, name = p.get('category', ''), p['title']
            scores = [3 if category == c else 2 if KEYWORDS[c] in name else 1 if category == {'미식':'음식점','문화':'문화시설','산책':'관광지','자연':'관광지','가족':'문화시설','역사':'문화시설'}[c] else 0 for c in request.categories]
            value = max(scores)
            if indoor:
                value += 3 if category in ('문화', '문화시설', '미식', '음식점') or any(w in name for w in ('박물관','미술관','체험관','전시관')) else -2
            return value
        pool = [p for p in pool if relevance(p) > 0]
        pace = request.pace
        speed = {'여유롭게': 2.5, '보통': 3.5, '활기차게': 4.5}[pace]
        if request.age_group == '60대 이상':
            speed = min(speed, 3)
        max_distance = min(7, request.duration_hours * speed * .45) * (.7 if indoor else 1)
        selected, total_distance, current, used_minutes = [], 0., coords, 0.
        while pool and len(selected) < min(5, request.duration_hours + 1):
            ranked = sorted(pool, key=lambda p: (-relevance(p) + distance_km(current, (p['latitude'],p['longitude'])) * 1.5, p['title']))
            chosen = None
            for p in ranked:
                leg = distance_km(current, (p['latitude'],p['longitude'])) * 1.3
                stay = 45 if p.get('category') in ('미식','음식점','문화','문화시설') else 25
                if total_distance + leg <= max_distance and used_minutes + leg / speed * 60 + stay <= request.duration_hours * 60:
                    chosen = (p, leg, stay)
                    break
            if chosen is None:
                break
            p, leg, stay = chosen
            selected.append(CourseStop(name=p['title'], latitude=p['latitude'], longitude=p['longitude'], category=p.get('category',''), address=p.get('addr',''), stay_minutes=stay, source=p['source']))
            total_distance += leg
            used_minutes += leg / speed * 60 + stay
            current = (p['latitude'], p['longitude'])
            pool.remove(p)
        if len(selected) < 2:
            raise HTTPException(404, "선택 조건 안에서 연결할 장소가 부족해요. 여행 시간을 늘리거나 관심 카테고리를 추가해주세요")
        notes = ["이동 거리는 직선거리 보정 추정치예요. 실제 보행 경로와 영업시간은 길찾기에서 확인해주세요."]
        if indoor:
            notes.append("날씨에 맞춰 실내 문화시설·음식점과 짧은 이동을 우선했어요. 야외 정류지는 현장 날씨를 확인해주세요.")
        if not weather and request.weather_mode == 'current':
            notes.append("현재 날씨를 확인하지 못해 기본 조건으로 만들었어요.")
        missing = [c for c in request.categories if not any(s.category == c or KEYWORDS[c] in s.name for s in selected)]
        if missing:
            notes.append("주변 장소와 이동 시간 제약으로 일부 관심사(" + ', '.join(missing) + ")는 포함되지 않았어요.")
        if request.gender != '선택 안 함':
            notes.append("성별로 장소를 제한하지 않고 선택한 관심사와 여행 속도를 우선 반영했어요.")
        course = CourseResponse(id=f"plan-{digest}", title=f"{request.region} {' · '.join(request.categories)}", description=f"{weather_label}, {pace} 둘러보는 {len(selected)}곳의 여행. {request.age_group} 여행자의 {request.duration_hours}시간 일정에 맞췄어요." if request.age_group != '선택 안 함' else f"{weather_label}, {pace} 둘러보는 {len(selected)}곳의 여행. {request.duration_hours}시간 일정에 맞췄어요.", sentiment_score=0, stops=selected, duration_label=f"약 {math.ceil(used_minutes / 10) * 10}분", category=request.categories[0], region=request.region, weather_label=weather_label, estimated_distance_km=round(total_distance,1), notes=notes, source='tourapi+kakao', image_url=next((p.get('image_url') for p in candidates if p['title'] in {s.name for s in selected} and p.get('image_url')), None))
        course.source = '+'.join(sorted({stop.source for stop in selected}))
        await cache_set(key, course.model_dump_json(), ex=7*86400)
        return course
