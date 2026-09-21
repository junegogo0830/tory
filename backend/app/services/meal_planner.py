import asyncio
import json
import logging
import re

from anthropic import Anthropic, APIError

from ..core.config import settings
from ..db.redis import cache_get, cache_set
from ..models.course import CourseResponse, CourseStop, MealType, RestaurantCandidateResponse, SelectedMeal
from .course_planner import distance_km
from .google_places import GooglePlacesService
from .kakao_local import KakaoLocalService
from .tourapi import TourApiService

logger = logging.getLogger(__name__)

_MODEL = "claude-haiku-4-5"
_SEARCH_RADIUS_M = 1500
_MAX_CANDIDATES_TO_CLAUDE = 8
_MAX_CANDIDATES_RETURNED = 6
_RETRIEVAL_CACHE_TTL_SECONDS = 3600  # 좌표/반경이 같으면 1시간 안엔 재검색하지 않는다.

# 카테고리 버튼(한식/중식/일식/양식/분식/카페·디저트)을 실제 데이터의 자유
# 텍스트 카테고리(TourAPI cat3/카카오 category_path)와 느슨하게 매칭한다.
_FOOD_CATEGORY_KEYWORDS: dict[str, tuple[str, ...]] = {
    "한식": ("한식", "국밥", "고기", "국수"),
    "중식": ("중식", "중국음식"),
    "일식": ("일식", "돈까스", "초밥", "라멘", "일본식"),
    "양식": ("양식", "피자", "파스타", "패스트푸드"),
    "분식": ("분식",),
    "카페/디저트": ("카페", "디저트", "베이커리", "제과"),
}

_MEAL_TYPE_LABELS: dict[MealType, str] = {"breakfast": "아침", "lunch": "점심", "dinner": "저녁"}

# Claude에게 넘기는 동선 이탈 정도 — 사용자에게 보여줄 reason에도 이 표현을
# 그대로 쓰게 유도해서, "detour"/숫자(m) 같은 개발 용어가 새어나가지 않게 한다.
_DETOUR_PHRASES = (
    (200, "코스 동선에서 거의 벗어나지 않음"),
    (500, "코스 동선에서 살짝 벗어남"),
    (1000, "코스 동선에서 다소 벗어남"),
)


def _detour_phrase(detour_m: int) -> str:
    for threshold, phrase in _DETOUR_PHRASES:
        if detour_m <= threshold:
            return phrase
    return "코스 동선에서 꽤 벗어남"


_SYSTEM_PROMPT = """당신은 "옛길" 앱의 식사 추천 도우미입니다.
이미 확정된 산책 코스에 식사를 추가하려고 합니다. 식사 시간대(아침/점심/저녁)
별로 후보 식당 목록이 주어지면, 시간대마다 후보 순위(+이유)를 매깁니다.

규칙:
- 각 시간대는 그 시간대에 주어진 후보 목록의 restaurant_id만 씁니다 — 새 식당을
  만들어내지 않고, 시간대끼리 후보를 섞지도 않습니다.
- 사용자가 고른 음식 카테고리·가격대·연령대는 데이터에 없으면 억지로 맞추지
  말고, 후보의 실제 이름·카테고리·코스 동선과의 관계를 근거로 참고 삼아
  (soft preference) 순위만 매깁니다.
- 동선에서 덜 벗어나는 곳을 우선합니다.
- reason은 자연스러운 한국어 한 줄로 씁니다 — "detour"라는 영어 단어나 구체적인
  거리(m) 숫자를 그대로 쓰지 말고, 후보에 같이 주어지는 동선 설명 표현을
  자연스럽게 녹여 씁니다.
- 후보를 지어내거나 목록에 없는 restaurant_id를 반환하지 않습니다.
- 출력은 반드시 "{"로 시작해서 "}"로 끝나는 순수 JSON 하나뿐이어야 합니다.
  설명 문장, 인사말, ```json 코드블록을 붙이지 마세요. 요청에 없던 시간대
  키는 넣지 않습니다.

{
  "breakfast": [{"restaurant_id": "...", "reason": "한 줄 이유"}, "..."],
  "lunch": [...],
  "dinner": [...]
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


def _meal_anchor_index(stop_count: int, meal_type: MealType) -> int:
    """식사 시간대별로 코스의 어느 정류지 근처에서 식당을 찾을지 정한다.
    시간표 기반 itinerary가 아직 없어 "아침은 초반, 저녁은 후반, 점심은 중간"
    이라는 단순하지만 합리적인 위치 휴리스틱을 쓴다."""
    if stop_count <= 1:
        return 0
    if meal_type == "breakfast":
        return 0
    if meal_type == "dinner":
        return stop_count - 1
    return stop_count // 2


def _insertion_detour_m(prev: CourseStop | None, next_: CourseStop | None, lat: float, lng: float) -> int:
    """이 좌표를 prev/next 사이에 끼워 넣을 때 늘어나는 이동거리(m).
    prev/next 중 하나가 없으면(코스 맨 앞/뒤) 있는 쪽까지 거리만 본다."""
    point = (lat, lng)
    if prev is None and next_ is None:
        return 0
    if prev is not None and prev.latitude is not None and next_ is not None and next_.latitude is not None:
        base = distance_km((prev.latitude, prev.longitude), (next_.latitude, next_.longitude))
        detour = (
            distance_km((prev.latitude, prev.longitude), point)
            + distance_km(point, (next_.latitude, next_.longitude))
            - base
        )
        return max(0, round(detour * 1000))
    anchor = prev if prev is not None and prev.latitude is not None else next_
    if anchor is None or anchor.latitude is None:
        return 0
    return round(distance_km((anchor.latitude, anchor.longitude), point) * 1000)


def _matches_food_categories(category_text: str, food_categories: list[str]) -> bool:
    if not food_categories:
        return True
    keywords: list[str] = []
    for label in food_categories:
        if label in ("상관없음", "기타"):
            return True
        keywords.extend(_FOOD_CATEGORY_KEYWORDS.get(label, (label,)))
    return any(keyword in category_text for keyword in keywords)


class MealPlannerService:
    """코스가 만들어진 뒤 "식사 추가" 단계에서만 쓰는 별도 파이프라인 —
    관광지 retrieval(course_generator.py/course_planner.py)과 완전히 분리된
    음식점 전용 retrieval + 랭킹이다. 관광지 코스 생성 로직은 이 서비스를
    전혀 모르고, 이 서비스도 관광지 후보를 다루지 않는다."""

    def __init__(
        self,
        tour_api_service: TourApiService | None = None,
        kakao_local_service: KakaoLocalService | None = None,
        google_places_service: GooglePlacesService | None = None,
        anthropic_client: Anthropic | None = None,
    ) -> None:
        self._tour_api_service = tour_api_service or TourApiService()
        self._kakao_local_service = kakao_local_service or KakaoLocalService()
        self._google_places_service = google_places_service or GooglePlacesService()
        self._client = anthropic_client

    def _get_client(self) -> Anthropic | None:
        if not settings.anthropic_api_key:
            return None
        if self._client is None:
            self._client = Anthropic(api_key=settings.anthropic_api_key, timeout=12, max_retries=0)
        return self._client

    async def find_candidates(
        self,
        course: CourseResponse,
        *,
        meal_types: list[MealType],
        food_categories: list[str],
        price_range: str | None,
        age_group: str | None,
    ) -> dict[str, list[RestaurantCandidateResponse]]:
        stops = [s for s in course.stops if s.latitude is not None and s.longitude is not None]
        if not stops:
            return {meal_type: [] for meal_type in meal_types}

        pools = await asyncio.gather(
            *(self._build_pool(stops, meal_type, food_categories) for meal_type in meal_types)
        )
        pools_by_type = dict(zip(meal_types, pools, strict=True))

        # Claude에 보내기 전, 사진 없는 후보(카카오 결과는 사진이 아예 없다)만
        # 구글 플레이스로 보강한다 — 이미 pool을 8개로 줄여둔 뒤라 호출량이 작다.
        await self._fill_missing_photos(pools_by_type, course.region)

        # 시간대별로 따로 Claude를 부르지 않고 한 번에 묶어서 호출한다 — 식사를
        # 여러 개 고르면(예: 점심+저녁) API 호출이 그만큼 줄어든다.
        ranked_by_type = await self._rank_with_claude(
            pools_by_type, food_categories=food_categories, price_range=price_range, age_group=age_group
        )
        return {
            meal_type: ranked_by_type.get(meal_type, pools_by_type[meal_type])[:_MAX_CANDIDATES_RETURNED]
            for meal_type in meal_types
        }

    async def _build_pool(
        self,
        stops: list[CourseStop],
        meal_type: MealType,
        food_categories: list[str],
    ) -> list[RestaurantCandidateResponse]:
        anchor_idx = _meal_anchor_index(len(stops), meal_type)
        anchor = stops[anchor_idx]
        prev_stop = stops[anchor_idx - 1] if anchor_idx > 0 else None
        next_stop = stops[anchor_idx + 1] if anchor_idx < len(stops) - 1 else None

        raw_candidates = await self._retrieve_restaurants(anchor.latitude, anchor.longitude, food_categories)
        scored: list[RestaurantCandidateResponse] = []
        seen_names: set[str] = set()
        for c in raw_candidates:
            if c["name"] in seen_names or c["latitude"] is None or c["longitude"] is None:
                continue
            category_text = f"{c.get('category', '')} {c.get('category_path', '')}"
            if not _matches_food_categories(category_text, food_categories):
                continue
            seen_names.add(c["name"])
            detour_m = _insertion_detour_m(prev_stop, next_stop, c["latitude"], c["longitude"])
            scored.append(
                RestaurantCandidateResponse(
                    restaurant_id=c["id"],
                    name=c["name"],
                    category=c.get("category", ""),
                    address=c.get("address", ""),
                    latitude=c["latitude"],
                    longitude=c["longitude"],
                    image_url=c.get("image_url"),
                    detour_m=detour_m,
                )
            )

        scored.sort(key=lambda r: r.detour_m if r.detour_m is not None else 10**9)
        return scored[:_MAX_CANDIDATES_TO_CLAUDE]

    async def _retrieve_restaurants(
        self, latitude: float, longitude: float, food_categories: list[str]
    ) -> list[dict]:
        """관광지 retrieval과 분리된 음식점 전용 검색 — TourAPI(음식점, contentTypeId=39)와
        카카오 로컬(FD6=음식점, 카페 카테고리를 골랐으면 CE7=카페도 함께)을 합친다.
        같은 좌표/반경/카테고리 조합은 1시간 동안 캐싱해 반복 호출을 줄인다
        (카테고리 필터링 자체는 캐싱 뒤에, 가벼운 로컬 연산으로 한다)."""
        include_cafe = any(label in ("카페/디저트", "상관없음") for label in food_categories) or not food_categories
        kakao_codes = ["FD6", "CE7"] if include_cafe else ["FD6"]

        cache_key = f"mealcandidates:v1:{round(latitude, 3)}:{round(longitude, 3)}:{_SEARCH_RADIUS_M}:{','.join(kakao_codes)}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return json.loads(cached)

        tour_task = self._tour_api_service.find_nearby_places(
            latitude=latitude, longitude=longitude, radius_m=_SEARCH_RADIUS_M, num_rows=15, content_type_id="39",
        )
        kakao_tasks = [
            self._kakao_local_service.search_restaurants(
                latitude=latitude, longitude=longitude, radius_m=_SEARCH_RADIUS_M, limit=15,
                sort="distance", category_group_code=code,
            )
            for code in kakao_codes
        ]
        tour_results, *kakao_results = await asyncio.gather(tour_task, *kakao_tasks)

        merged: list[dict] = []
        for place in tour_results:
            if not place.get("title") or place.get("latitude") is None:
                continue
            merged.append({
                # find_nearby_places()는 contentId를 안 돌려줘서(좌표 검색 응답엔 없음)
                # 이름을 id 대신 쓴다 — 이 후보 목록 안에서만 유일하면 충분하다.
                "id": f"tour-{place['title']}",
                "name": place["title"],
                "category": place.get("category", "음식점"),
                "address": place.get("addr", ""),
                "latitude": place["latitude"],
                "longitude": place["longitude"],
                "image_url": place.get("image_url"),
            })
        for places in kakao_results:
            for place in places:
                if not place.get("id") or place.get("latitude") is None:
                    continue
                merged.append({
                    "id": f"kakao-{place['id']}",
                    "name": place["name"],
                    "category": place.get("category", "음식점"),
                    "category_path": place.get("category_path", ""),
                    "address": place.get("address", ""),
                    "latitude": place["latitude"],
                    "longitude": place["longitude"],
                    "image_url": None,  # 카카오 로컬 API엔 사진이 없다 — 구글 플레이스로 나중에 보강.
                })

        await cache_set(cache_key, json.dumps(merged), ex=_RETRIEVAL_CACHE_TTL_SECONDS)
        return merged

    async def _fill_missing_photos(
        self, pools_by_type: dict[MealType, list[RestaurantCandidateResponse]], region: str
    ) -> None:
        """TourAPI/카카오에 사진이 없는 후보(카카오는 아예 사진 필드가 없다)를
        구글 플레이스로 보강한다 — 코스 정류지 사진 보강과 같은 소스라, 여기서
        채운 image_url이 그대로 코스에 삽입될 때도 따라간다."""
        seen_ids: set[str] = set()
        targets: list[RestaurantCandidateResponse] = []
        for pool in pools_by_type.values():
            for candidate in pool:
                if candidate.image_url is None and candidate.restaurant_id not in seen_ids:
                    seen_ids.add(candidate.restaurant_id)
                    targets.append(candidate)
        if not targets:
            return

        photos = await asyncio.gather(
            *(self._google_places_service.find_photo(c.name, region or None) for c in targets)
        )
        photo_by_id = {
            c.restaurant_id: photo for c, photo in zip(targets, photos, strict=True) if photo is not None
        }
        if not photo_by_id:
            return

        for meal_type, pool in pools_by_type.items():
            pools_by_type[meal_type] = [
                c.model_copy(update={
                    "image_url": photo_by_id[c.restaurant_id]["image_url"],
                    "photo_attribution_name": photo_by_id[c.restaurant_id]["attribution_name"],
                    "photo_attribution_url": photo_by_id[c.restaurant_id]["attribution_url"],
                })
                if c.restaurant_id in photo_by_id else c
                for c in pool
            ]

    async def _rank_with_claude(
        self,
        pools_by_type: dict[MealType, list[RestaurantCandidateResponse]],
        *,
        food_categories: list[str],
        price_range: str | None,
        age_group: str | None,
    ) -> dict[MealType, list[RestaurantCandidateResponse]]:
        """Claude는 시간대별 pool 안에서 순위(+이유)만 매긴다 — 새 식당을 만들지
        않는다. 모든 시간대를 한 번의 호출로 처리한다(호출량 절감). 실패하거나
        특정 시간대 응답이 비정상이면 그 시간대만 조용히 detour 순서로 폴백한다."""
        non_empty = {mt: pool for mt, pool in pools_by_type.items() if pool}
        if not non_empty:
            return dict(pools_by_type)

        client = self._get_client()
        if client is None:
            return dict(pools_by_type)

        by_id_per_type = {mt: {c.restaurant_id: c for c in pool} for mt, pool in non_empty.items()}
        prefs = ", ".join(
            filter(None, ["+".join(food_categories) if food_categories else None, price_range, age_group])
        ) or "상관없음"

        sections = []
        for meal_type, pool in non_empty.items():
            lines = "\n".join(
                f"- id={c.restaurant_id} | {c.name} ({c.category}) | {_detour_phrase(c.detour_m or 0)}"
                for c in pool
            )
            sections.append(f"[{_MEAL_TYPE_LABELS.get(meal_type, meal_type)}]\n후보:\n{lines}")
        user_prompt = f"취향: {prefs}\n\n" + "\n\n".join(sections)

        try:
            response = await asyncio.to_thread(
                client.messages.create,
                model=_MODEL,
                max_tokens=1024,
                system=_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_prompt}],
            )
        except APIError:
            logger.exception("Claude meal ranking failed for meal_types=%s", list(non_empty))
            return dict(pools_by_type)

        text = next((block.text for block in response.content if block.type == "text"), "")
        try:
            data = json.loads(_extract_json(text))
            if not isinstance(data, dict):
                raise ValueError("응답은 시간대별 딕셔너리여야 해요")
        except ValueError:
            logger.warning("Claude meal ranking response was invalid: %r", text[:300])
            return dict(pools_by_type)

        result = dict(pools_by_type)
        for meal_type, by_id in by_id_per_type.items():
            recommendations = data.get(meal_type)
            if not isinstance(recommendations, list):
                continue  # 이 시간대만 폴백(원래 pool 그대로 유지).

            ranked: list[RestaurantCandidateResponse] = []
            seen_ids: set[str] = set()
            for item in recommendations:
                if not isinstance(item, dict):
                    continue
                restaurant_id = item.get("restaurant_id")
                candidate = by_id.get(restaurant_id)
                if candidate is None or restaurant_id in seen_ids:
                    continue  # RAG pool 밖 id는 버린다 — hallucination 방지.
                seen_ids.add(restaurant_id)
                reason = item.get("reason")
                ranked.append(candidate.model_copy(update={"reason": str(reason) if reason else None}))

            if not ranked:
                continue
            ranked.extend(c for c in non_empty[meal_type] if c.restaurant_id not in seen_ids)
            result[meal_type] = ranked
        return result

    def insert_meals(self, course: CourseResponse, meals: list[SelectedMeal]) -> CourseResponse:
        """선택된 식당을 기존 코스에 끼워 넣는다 — Claude를 다시 부르지 않고
        코드로 결정론적으로 계산한다(순수 거리 최적화라 의미 판단이 필요 없다).
        같은 코스에 이미 있던 식사(is_meal=True) 정류지는 이번 요청의 meals로
        전부 교체한다 — "식사 변경/삭제"도 이 메서드 하나로 처리된다."""
        base_stops = [s for s in course.stops if not s.is_meal]

        stops = list(base_stops)
        for meal in meals:
            stops = self._insert_one(stops, meal)

        estimated_distance_km = None
        coords = [(s.latitude, s.longitude) for s in stops if s.latitude is not None and s.longitude is not None]
        if len(coords) == len(stops) and len(coords) >= 2:
            estimated_distance_km = round(
                sum(distance_km(coords[i], coords[i + 1]) for i in range(len(coords) - 1)), 1
            )

        return course.model_copy(update={"stops": stops, "estimated_distance_km": estimated_distance_km})

    def _insert_one(self, stops: list[CourseStop], meal: SelectedMeal) -> list[CourseStop]:
        restaurant = meal.restaurant
        meal_stop = CourseStop(
            name=restaurant.name,
            source="meal",
            latitude=restaurant.latitude,
            longitude=restaurant.longitude,
            category=restaurant.category or "음식점",
            address=restaurant.address,
            stay_minutes=60,
            image_url=restaurant.image_url,
            photo_attribution_name=restaurant.photo_attribution_name,
            photo_attribution_url=restaurant.photo_attribution_url,
            is_meal=True,
            meal_type=meal.meal_type,
        )
        if restaurant.latitude is None or restaurant.longitude is None or not stops:
            # 좌표가 없으면(드묾) 동선 계산이 불가능하니 그냥 순서상 자연스러운
            # 위치(아침=맨앞, 저녁=맨뒤, 점심=중간)에 넣는다.
            idx = _meal_anchor_index(len(stops), meal.meal_type)
            return stops[:idx] + [meal_stop] + stops[idx:]

        best_idx, best_detour = 0, None
        for idx in range(len(stops) + 1):
            prev_stop = stops[idx - 1] if idx > 0 else None
            next_stop = stops[idx] if idx < len(stops) else None
            detour = _insertion_detour_m(prev_stop, next_stop, restaurant.latitude, restaurant.longitude)
            if best_detour is None or detour < best_detour:
                best_idx, best_detour = idx, detour
        return stops[:best_idx] + [meal_stop] + stops[best_idx:]
