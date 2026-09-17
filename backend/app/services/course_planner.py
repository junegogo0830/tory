"""Fast, reproducible routes using only places returned by tourism/place APIs."""
import asyncio
import hashlib
import json
import logging
import math
import re
from datetime import datetime
from zoneinfo import ZoneInfo

from anthropic import Anthropic, APIError
from fastapi import HTTPException

from ..core.config import settings
from ..db.redis import cache_get, cache_set
from ..models.course import CourseGenerateRequest, CourseResponse, CourseStop
from .google_places import GooglePlacesService
from .tourapi import TourApiService
from .kakao_local import KakaoLocalService
from .tourism_filters import looks_non_touristy
from .weather import WeatherService

logger = logging.getLogger(__name__)

_MODEL = "claude-haiku-4-5"

# 관심사별로 세 소스(국문 관광정보 API/카카오 로컬/구글 플레이스)를 각각 어떤
# 필터로 조회할지 정의한다. 예전엔 TourAPI를 필터 없이 통째로 가져온 뒤 이름에
# 키워드가 들어있는지("공원"이 이름에 있으면 산책)로 관련도를 추측했는데,
# 상호명에 우연히 키워드가 들어간 엉뚱한 업체가 섞이는 문제가 있었다 —
# 이제는 애초에 각 API의 카테고리 필터로 조회 시점에 걸러서 가져온다.
# TourAPI contenttypeid: 12=관광지, 14=문화시설, 28=레포츠, 39=음식점.
# TourAPI cat1(대분류): A01=자연, A02=인문(역사/체험/휴양/문화시설 등) — "관광지(12)"
# 하나로는 노인회 사무실·사우나 같은 A02 하위 오분류까지 섞여 들어와서(실측 확인:
# "대한노인회 OO지회"가 cat2=A0203 체험관광지로, "OO사우나"가 cat2=A0202 휴양관광지로
# 등록돼 있었다), 순수 자연 경관이어야 하는 산책/자연은 cat1=A01로 한 번 더 좁힌다.
# 카카오 category_group_code: AT4=관광명소, CT1=문화시설, FD6=음식점, CE7=카페.
CATEGORY_TAXONOMY: dict[str, dict] = {
    "산책": {
        "tour_types": ("12",), "tour_cat1": {"A01"}, "kakao_codes": (),
        "google_types": {"park", "tourist_attraction", "natural_feature"},
        "stay_minutes": 25,
    },
    "역사": {
        "tour_types": ("12", "14"), "tour_cat1": {"A02"}, "kakao_codes": (),
        "google_types": {"tourist_attraction", "museum", "place_of_worship"},
        "stay_minutes": 35,
    },
    "미식": {
        "tour_types": ("39",), "tour_cat1": None, "kakao_codes": ("FD6", "CE7"),
        "google_types": {"restaurant", "cafe", "bakery"},
        "stay_minutes": 50,
    },
    "문화": {
        "tour_types": ("14",), "tour_cat1": None, "kakao_codes": ("CT1",),
        "google_types": {"museum", "art_gallery"},
        "stay_minutes": 40,
    },
    "자연": {
        "tour_types": ("12",), "tour_cat1": {"A01"}, "kakao_codes": (),
        "google_types": {"park", "natural_feature", "zoo", "aquarium"},
        "stay_minutes": 30,
    },
    "가족": {
        "tour_types": ("12", "28", "14"), "tour_cat1": None, "kakao_codes": (),
        "google_types": {"amusement_park", "aquarium", "zoo", "museum"},
        "stay_minutes": 40,
    },
}
# 실내(비/눈/더위/추위) 날씨일 때 우선하는 관심사 — 문화시설·식당은 실내,
# 나머지(산책·역사 유적지·자연·야외 체험)는 대부분 야외라 감점한다.
_INDOOR_CATEGORIES = {"문화", "미식"}

_SOURCE_PRIORITY = {"tourapi": 0, "google": 1, "kakao": 2}

_POLISH_SYSTEM_PROMPT = """당신은 "옛길" 앱의 코스 마무리 담당자입니다.
이미 확정된 정류지 목록(이동거리·소요시간 제약을 모두 통과한 실제 장소들)의
방문 순서를 더 자연스러운 동선으로 다듬고, 제목과 소개 문장을 씁니다.

규칙:
- 정류지를 추가하거나 빼거나 새로 지어내지 않습니다 — 주어진 이름 그대로,
  개수 그대로 순서만 바꿀 수 있습니다.
- 지리적으로 되돌아가지 않는(지그재그 없는) 자연스러운 동선을 우선합니다.
- 제목은 지역·계절감·분위기가 드러나게 간결하게, 소개는 1~2문장으로 씁니다.
- 출력은 반드시 "{"로 시작해서 "}"로 끝나는 순수 JSON 하나뿐이어야 합니다.
  설명 문장, 인사말, ```json 같은 마크다운 코드블록을 절대 붙이지 마세요.

{
  "order": ["정류지 이름 그대로", "..."],
  "title": "코스 제목",
  "description": "1~2문장 소개"
}"""

_CODE_FENCE_RE = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.DOTALL)


def _extract_json(text: str) -> str:
    fenced = _CODE_FENCE_RE.search(text)
    if fenced:
        return fenced.group(1)
    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end != -1 and end > start:
        return text[start : end + 1]
    return text


def distance_km(a, b):
    lat1, lng1, lat2, lng2 = map(math.radians, (*a, *b))
    v = math.sin((lat2-lat1)/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin((lng2-lng1)/2)**2
    return 6371 * 2 * math.asin(min(1, math.sqrt(v)))


def _same_place(a: str, b: str) -> bool:
    """두 후보가 사실상 같은 장소인지 이름으로 어림잡아 판단한다(좌표 근접과
    함께 써야 한다 — 이름만으로는 다른 동네의 동명 장소와도 겹칠 수 있다)."""
    a, b = a.strip(), b.strip()
    return a == b or a in b or b in a or (len(a) >= 4 and len(b) >= 4 and a[:4] == b[:4])


class CoursePlanner:
    def __init__(self, tour=None, kakao=None, weather=None, google_places=None, anthropic_client=None):
        self.tour = tour or TourApiService()
        self.kakao = kakao or KakaoLocalService()
        self.weather = weather or WeatherService()
        self.google_places = google_places or GooglePlacesService()
        self._client = anthropic_client

    def _get_client(self) -> Anthropic | None:
        if not settings.anthropic_api_key:
            return None
        if self._client is None:
            self._client = Anthropic(api_key=settings.anthropic_api_key, timeout=10, max_retries=0)
        return self._client

    async def generate(self, request: CourseGenerateRequest) -> CourseResponse:
        request = request.model_copy(update={"region": request.region.strip(), "categories": list(dict.fromkeys(request.categories))})
        if len(request.region) < 2:
            raise HTTPException(422, "지역을 선택해주세요")
        # Short-lived plan cache includes every preference and the current weather time bucket.
        bucket = datetime.now(ZoneInfo("Asia/Seoul")).strftime("%Y%m%d%H")
        digest = hashlib.sha256(("v3:" + request.model_dump_json() + bucket).encode()).hexdigest()[:24]
        key = f"course-detail:plan-{digest}"
        cached = await cache_get(key)
        if cached:
            return CourseResponse.model_validate_json(cached)
        coords = await self.kakao.geocode(request.region)
        if not coords:
            raise HTTPException(404, "지역 위치를 찾지 못했어요. 시·군·구를 다시 선택해주세요")

        async def category_candidates(category: str) -> list[dict]:
            cfg = CATEGORY_TAXONOMY[category]
            tour_groups, kakao_groups = await asyncio.gather(
                asyncio.gather(*(
                    self.tour.find_nearby_places(latitude=coords[0], longitude=coords[1], radius_m=5000, num_rows=20, content_type_id=t)
                    for t in cfg["tour_types"]
                )),
                asyncio.gather(*(
                    self.kakao.search_restaurants(latitude=coords[0], longitude=coords[1], radius_m=5000, limit=15, category_group_code=code)
                    for code in cfg["kakao_codes"]
                )),
            )
            allowed_cat1 = cfg["tour_cat1"]
            items = [
                {**p, "source": "tourapi", "matched_categories": {category}}
                for group in tour_groups for p in group
                if not allowed_cat1 or not p.get("cat1") or p["cat1"] in allowed_cat1
            ]
            items += [
                {
                    "title": p["name"], "addr": p["address"], "latitude": p["latitude"], "longitude": p["longitude"],
                    "image_url": None, "source": "kakao", "matched_categories": {category},
                }
                for group in kakao_groups for p in group
            ]
            return items

        weather, *category_results = await asyncio.gather(
            self.weather.get_current_weather(*coords), *(category_candidates(c) for c in request.categories)
        )
        combined = [p for group in category_results for p in group]

        # 좌표/이름이 없거나 반경 밖인 후보, 상호명으로 봐도 관광 목적이 아닌
        # 일반 행정·생활 시설(주민센터/노인회/사우나 등)은 애초에 후보 풀에서 제외한다.
        valid = []
        for p in combined:
            lat, lng = p.get("latitude"), p.get("longitude")
            if not p.get("title") or lat is None or lng is None or not (-90 <= lat <= 90 and -180 <= lng <= 180):
                continue
            if distance_km(coords, (lat, lng)) > 7:
                continue
            if looks_non_touristy(p["title"]):
                continue
            valid.append(p)

        deduped = self._dedup(valid)

        # 관심사 필터로 좁힌 뒤에도 후보가 얕으면(관광지 등록이 적은 동네) 구글
        # 플레이스 Nearby Search로 보강한다 — 이쪽도 카테고리별 허용 타입에
        # 매칭되는 것만 후보로 받아들인다(옷가게·은행 등은 애초에 안 들어온다).
        if len(deduped) < 15:
            google_raw = await self.google_places.find_nearby(latitude=coords[0], longitude=coords[1], radius_m=5000, num_rows=20)
            google_items = []
            for g in google_raw:
                matched = {c for c in request.categories if CATEGORY_TAXONOMY[c]["google_types"] & set(g.get("types", []))}
                if not matched or looks_non_touristy(g["title"]):
                    continue
                google_items.append({
                    "title": g["title"], "latitude": g["latitude"], "longitude": g["longitude"], "addr": g.get("address", ""),
                    "image_url": g.get("image_url"), "photo_attribution_name": g.get("attribution_name"),
                    "photo_attribution_url": g.get("attribution_url"), "source": "google", "matched_categories": matched,
                })
            deduped = self._dedup(deduped + google_items)

        mode = request.weather_mode
        weather_label = {"clear": "맑은 날", "rain": "비 오는 날", "snow": "눈 오는 날", "hot": "더운 날", "cold": "추운 날"}.get(mode, "현재 날씨 확인 불가")
        if mode == 'current' and weather:
            weather_label = f"{weather.description} · {weather.temperature:.0f}°C"
            mode = 'rain' if weather.condition.startswith('rain') else 'snow' if weather.condition.startswith('snow') else 'hot' if weather.temperature >= 30 else 'cold' if weather.temperature <= 0 else 'clear'
        indoor = mode in ('rain', 'snow', 'hot', 'cold')

        requested = set(request.categories)

        def relevance(p):
            matched = p["matched_categories"] & requested
            if not matched:
                return 0
            value = len(matched) * 2
            if indoor:
                value += 2 if matched & _INDOOR_CATEGORIES else -2
            return value

        pool = [p for p in deduped if relevance(p) > 0]
        pace = request.pace
        speed = {'여유롭게': 2.5, '보통': 3.5, '활기차게': 4.5}[pace]
        if request.age_group == '60대 이상':
            speed = min(speed, 3)
        max_distance = min(7, request.duration_hours * speed * .45) * (.7 if indoor else 1)
        selected, selected_raw, total_distance, current, used_minutes = [], [], 0., coords, 0.
        while pool and len(selected) < min(5, request.duration_hours + 1):
            ranked = sorted(pool, key=lambda p: (-relevance(p) + distance_km(current, (p['latitude'], p['longitude'])) * 1.5, p['title']))
            chosen = None
            for p in ranked:
                leg = distance_km(current, (p['latitude'], p['longitude'])) * 1.3
                stay = max(CATEGORY_TAXONOMY[c]["stay_minutes"] for c in p["matched_categories"] & requested)
                if total_distance + leg <= max_distance and used_minutes + leg / speed * 60 + stay <= request.duration_hours * 60:
                    chosen = (p, leg, stay)
                    break
            if chosen is None:
                break
            p, leg, stay = chosen
            primary_category = next(c for c in request.categories if c in p["matched_categories"])
            p["stay"] = stay
            selected.append(CourseStop(name=p['title'], latitude=p['latitude'], longitude=p['longitude'], category=primary_category, address=p.get('addr', ''), stay_minutes=stay, source=p['source'], image_url=p.get('image_url')))
            selected_raw.append(p)
            total_distance += leg
            used_minutes += leg / speed * 60 + stay
            current = (p['latitude'], p['longitude'])
            pool.remove(p)
        if len(selected) < 2:
            raise HTTPException(404, "선택 조건 안에서 연결할 장소가 부족해요. 여행 시간을 늘리거나 관심 카테고리를 추가해주세요")

        # 카카오 로컬 후보는 애초에 사진을 안 주고, TourAPI 후보도 대표사진이
        # 없는 경우가 흔하다(식당류 특히) — 최종 선택된(최대 5곳) 정류지만
        # 구글 플레이스로 사진을 보강한다. 후보 선정(관심사 매칭) 로직 자체는
        # 건드리지 않는다 — 여기서 걸러버리면 관광지 적은 동네에서 "장소 부족"
        # 에러가 더 자주 난다.
        async def stop_photo(stop: CourseStop) -> dict | None:
            if stop.image_url:
                return None  # 이미 있음(TourAPI/구글 출처) — 그대로 둔다.
            return await self.google_places.find_photo(stop.name, request.region)
        photos = await asyncio.gather(*(stop_photo(s) for s in selected))
        selected = [
            s if photo is None else s.model_copy(update={
                'image_url': photo['image_url'],
                'photo_attribution_name': photo['attribution_name'],
                'photo_attribution_url': photo['attribution_url'],
            })
            for s, photo in zip(selected, photos, strict=True)
        ]

        title = f"{request.region} {' · '.join(request.categories)}"
        description = f"{weather_label}, {pace} 둘러보는 {len(selected)}곳의 여행. {request.age_group} 여행자의 {request.duration_hours}시간 일정에 맞췄어요." if request.age_group != '선택 안 함' else f"{weather_label}, {pace} 둘러보는 {len(selected)}곳의 여행. {request.duration_hours}시간 일정에 맞췄어요."
        polished = await self._polish_with_claude(
            request=request, selected=selected, selected_raw=selected_raw, coords=coords,
            speed=speed, max_distance=max_distance, weather_label=weather_label, indoor=indoor,
        )
        if polished is not None:
            selected, total_distance, used_minutes, title, description = polished

        notes = ["이동 거리는 직선거리 보정 추정치예요. 실제 보행 경로와 영업시간은 길찾기에서 확인해주세요."]
        if indoor:
            notes.append("날씨에 맞춰 실내 문화시설·음식점과 짧은 이동을 우선했어요. 야외 정류지는 현장 날씨를 확인해주세요.")
        if not weather and request.weather_mode == 'current':
            notes.append("현재 날씨를 확인하지 못해 기본 조건으로 만들었어요.")
        satisfied = set().union(*(p["matched_categories"] for p in selected_raw)) if selected_raw else set()
        missing = [c for c in request.categories if c not in satisfied]
        if missing:
            notes.append("주변 장소와 이동 시간 제약으로 일부 관심사(" + ', '.join(missing) + ")는 포함되지 않았어요.")
        if request.gender != '선택 안 함':
            notes.append("성별로 장소를 제한하지 않고 선택한 관심사와 여행 속도를 우선 반영했어요.")
        course_image_url = next((s.image_url for s in selected if s.image_url), None)
        course = CourseResponse(id=f"plan-{digest}", title=title, description=description, sentiment_score=0, stops=selected, duration_label=f"약 {math.ceil(used_minutes / 10) * 10}분", category=request.categories[0], region=request.region, weather_label=weather_label, estimated_distance_km=round(total_distance, 1), notes=notes, source='tourapi+kakao', image_url=course_image_url)
        course.source = '+'.join(sorted({stop.source for stop in selected}))
        await cache_set(key, course.model_dump_json(), ex=7*86400)
        return course

    def _dedup(self, items: list[dict]) -> list[dict]:
        """같은 장소가 여러 소스/여러 관심사 조회에서 중복으로 나오면 하나로
        합친다(관심사 태그는 합집합으로 보존한다). 소스 우선순위는 TourAPI(공식
        큐레이션) > 구글(출처 표기 포함) > 카카오(사진 없음, 나중에 보강 필요) 순."""
        ordered = sorted(items, key=lambda p: _SOURCE_PRIORITY.get(p["source"], 3))
        kept: list[dict] = []
        for p in ordered:
            dup = next(
                (
                    k for k in kept
                    if distance_km((p["latitude"], p["longitude"]), (k["latitude"], k["longitude"])) < 0.06
                    and _same_place(p["title"], k["title"])
                ),
                None,
            )
            if dup is not None:
                dup["matched_categories"] = dup["matched_categories"] | p["matched_categories"]
                continue
            kept.append(p)
        return kept

    async def _polish_with_claude(
        self, *, request: CourseGenerateRequest, selected: list[CourseStop], selected_raw: list[dict],
        coords: tuple[float, float], speed: float, max_distance: float, weather_label: str, indoor: bool,
    ) -> tuple[list[CourseStop], float, float, str, str] | None:
        """확정된 정류지(관심사·거리·시간 제약을 이미 통과한 실제 장소들)의
        방문 순서와 제목/소개만 Claude로 다듬는다. 장소 자체는 절대 새로
        고르게 하지 않는다 — 순서를 바꾼 결과가 실제로 거리/시간 제약을
        지키는지 서버에서 다시 계산해 검증하고, 조금이라도 어긋나면(이름이
        하나라도 다르거나, 제약을 넘거나, 응답이 이상하면) 그냥 기존 순서와
        정형 문구로 폴백한다 — 실패해도 사용자에게 티 안 나는 안전망이다."""
        client = self._get_client()
        if client is None or len(selected) < 2:
            return None

        lines = "\n".join(
            f"- {s.name} ({', '.join(sorted(r['matched_categories']))}, {s.address})"
            for s, r in zip(selected, selected_raw)
        )
        prompt = (
            f"지역: {request.region}\n관심사: {', '.join(request.categories)}\n"
            f"여행 속도: {request.pace} · 총 시간: {request.duration_hours}시간 · 날씨: {weather_label}"
            + (f" · {request.age_group}" if request.age_group != '선택 안 함' else "")
            + f"\n\n확정된 정류지({len(selected)}곳, 개수/장소는 그대로 유지):\n{lines}"
        )
        try:
            response = await asyncio.to_thread(
                client.messages.create, model=_MODEL, max_tokens=512,
                system=_POLISH_SYSTEM_PROMPT, messages=[{"role": "user", "content": prompt}],
            )
        except APIError:
            logger.exception("Claude course polish failed for region=%s", request.region)
            return None

        text = next((block.text for block in response.content if block.type == "text"), "")
        try:
            data = json.loads(_extract_json(text))
        except ValueError:
            logger.warning("Claude course polish response was not valid JSON: %r", text[:300])
            return None
        if not isinstance(data, dict):
            return None
        order, title, description = data.get("order"), data.get("title"), data.get("description")
        if (
            not isinstance(order, list) or not isinstance(title, str) or not isinstance(description, str)
            or not title.strip() or not description.strip()
        ):
            return None

        by_name = {s.name: (s, r) for s, r in zip(selected, selected_raw)}
        if len(order) != len(selected) or {n for n in order if isinstance(n, str)} != set(by_name):
            logger.warning("Claude course polish reordered/invented stops, discarding: %r", order)
            return None

        reordered = [by_name[name] for name in order]
        total_distance, used_minutes, current = 0., 0., coords
        for stop, raw in reordered:
            leg = distance_km(current, (stop.latitude, stop.longitude)) * 1.3
            total_distance += leg
            used_minutes += leg / speed * 60 + raw["stay"]
            current = (stop.latitude, stop.longitude)
        if total_distance > max_distance or used_minutes > request.duration_hours * 60:
            logger.info("Claude course polish order broke distance/time budget, discarding")
            return None

        return [stop for stop, _ in reordered], total_distance, used_minutes, title.strip(), description.strip()
