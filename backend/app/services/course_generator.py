import asyncio
import json
import logging
import re

from anthropic import Anthropic, APIError

from ..core.config import settings
from ..db.redis import cache_get, cache_set
from ..models.course import CourseResponse, CourseStop
from ..models.location import LocationResponse
from .tourapi import TourApiService

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 3600 * 24 * 30  # 계절별 코스라 자주 안 바뀌어도 된다.
_SEARCH_RADIUS_M = 3000
_MODEL = "claude-haiku-4-5"

_SYSTEM_PROMPT = """당신은 "옛길" 앱의 동네 여행 코스 기획자입니다.
사용자가 예전에 살던 동네 근처를 오늘 다시 걸어보는 코스를 만듭니다.

규칙:
- 반드시 제공된 후보 목록에 있는 장소 이름만 정류지로 씁니다 (새로 지어내지 않음).
- 3~4개 정류지를 실제로 걸어서 이동하기 합리적인 순서로 고릅니다.
- 계절에 어울리는 정류지/설명을 우선합니다.
- 출력은 반드시 "{"로 시작해서 "}"로 끝나는 순수 JSON 하나뿐이어야 합니다.
  설명 문장, 인사말, ```json 같은 마크다운 코드블록을 절대 붙이지 마세요.

{
  "title": "코스 제목 (계절감이 드러나게)",
  "description": "1~2문장 소개",
  "duration_label": "약 N시간 형식",
  "category": "산책 | 역사 | 미식 중 하나",
  "sentiment_score": 0.0~1.0 사이 숫자 (이 코스가 얼마나 매력적인지),
  "stops": ["후보 목록에 있는 장소명 그대로", "..."]
}"""


_CODE_FENCE_RE = re.compile(r"```(?:json)?\s*(.*?)\s*```", re.DOTALL)


def _extract_json(text: str) -> str:
    """Claude가 지침에도 불구하고 ```json 코드블록으로 감싸거나 앞뒤에 설명을
    붙이는 경우가 있어, 순수 JSON 객체만 뽑아낸다."""
    fenced = _CODE_FENCE_RE.search(text)
    if fenced:
        return fenced.group(1)

    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end != -1 and end > start:
        return text[start : end + 1]

    return text


class CourseGeneratorService:
    """좌표 기반으로 실제 주변 장소를 찾아 LLM(Claude Haiku)으로 계절별 코스를 만든다.

    옛길 팀이 큐레이션한 3곳(순천/군산/영월)은 이 서비스를 타지 않고 기존
    RecommendationService의 손으로 다듬은 코스를 그대로 쓴다 — 여기는 그 3곳
    밖에서 검색으로 찾은 임의의 장소(예: 내가 살던 동네)를 위한 것이다.
    """

    def __init__(
        self,
        tour_api_service: TourApiService | None = None,
        anthropic_client: Anthropic | None = None,
    ) -> None:
        self._tour_api_service = tour_api_service or TourApiService()
        self._client = anthropic_client

    def _get_client(self) -> Anthropic | None:
        if not settings.anthropic_api_key:
            return None
        if self._client is None:
            self._client = Anthropic(api_key=settings.anthropic_api_key, timeout=12, max_retries=0)
        return self._client

    async def generate_course(self, location: LocationResponse, season: str) -> CourseResponse | None:
        if location.latitude is None or location.longitude is None:
            return None

        cache_key = f"gencourse:{location.id}:{season}"
        cached = await cache_get(cache_key)
        if cached is not None:
            course = CourseResponse.model_validate_json(cached) if cached != "null" else None
            if course:
                await cache_set(f"course-detail:{course.id}", course.model_dump_json(), ex=_CACHE_TTL_SECONDS)
            return course

        course = await self._generate(location, season)

        await cache_set(cache_key, course.model_dump_json() if course else "null",
                        ex=_CACHE_TTL_SECONDS if course else 60)
        if course:
            await cache_set(f"course-detail:{course.id}", course.model_dump_json(), ex=_CACHE_TTL_SECONDS)
        return course

    async def _generate(self, location: LocationResponse, season: str) -> CourseResponse | None:
        client = self._get_client()
        if client is None:
            return None

        candidates = await self._tour_api_service.find_nearby_places(
            latitude=location.latitude, longitude=location.longitude, radius_m=_SEARCH_RADIUS_M
        )
        if len(candidates) < 2:
            return None

        candidate_lines = "\n".join(
            f"- {c['title']} ({c['category']}, {c['distance_m']}m, {c['addr']})" for c in candidates
        )
        user_prompt = (
            f"장소: {location.name} ({location.region})\n계절: {season}\n\n"
            f"반경 {_SEARCH_RADIUS_M}m 이내 실제 후보:\n{candidate_lines}"
        )

        try:
            response = await asyncio.to_thread(client.messages.create,
                model=_MODEL,
                max_tokens=1024,
                system=_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": user_prompt}],
            )
        except APIError:
            logger.exception("Claude course generation failed for location_id=%s", location.id)
            return None

        text = next((block.text for block in response.content if block.type == "text"), "")
        return self._parse_course(text, location=location, season=season, candidates=candidates)

    def _parse_course(
        self, text: str, *, location: LocationResponse, season: str, candidates: list[dict]
    ) -> CourseResponse | None:
        try:
            data = json.loads(_extract_json(text))
        except ValueError:
            logger.warning(
                "Claude course response was not valid JSON for location_id=%s: %r",
                location.id, text[:300],
            )
            return None

        if not isinstance(data, dict) or not isinstance(data.get("stops"), list):
            return None
        candidates_by_name = {c["title"]: c for c in candidates}
        stop_names = list(dict.fromkeys(s for s in data["stops"] if isinstance(s, str) and s in candidates_by_name))[:4]
        if len(stop_names) < 2:
            logger.warning("Claude course had too few real stops for location_id=%s", location.id)
            return None

        stops = [
            CourseStop(
                name=name,
                latitude=candidates_by_name[name]["latitude"],
                longitude=candidates_by_name[name]["longitude"],
                category=candidates_by_name[name].get("category", ""),
                address=candidates_by_name[name].get("addr", ""),
                image_url=candidates_by_name[name].get("image_url"),
            )
            for name in stop_names
        ]

        try:
            return CourseResponse(
                id=f"llm-{location.id}-{season}",
                location_id=location.id,
                title=str(data["title"]),
                description=str(data["description"]),
                sentiment_score=max(0.0, min(1.0, float(data["sentiment_score"]))),
                stops=stops,
                duration_label=str(data["duration_label"]),
                category=str(data.get("category", "산책")),
            )
        except (KeyError, ValueError, TypeError):
            logger.warning("Claude course response missing/invalid fields for location_id=%s", location.id)
            return None
