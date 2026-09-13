import asyncio
import hashlib
import json
import logging
from email.utils import parsedate_to_datetime
from urllib.parse import urlparse

import httpx
from anthropic import Anthropic, APIError

from ..core.config import settings
from ..core.text import simplify_place_name, strip_html
from ..db.redis import cache_get, cache_set
from ..models.news import NewsItemResponse, RegionStoryResponse
from .tourapi import TourApiService

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 1800  # 뉴스는 장소 정보보다 자주 바뀌므로 짧게 캐싱.
# 그 시절 이야기는 과거에 있었던 일이라 안 바뀐다 — 사실상 영구 캐싱(1년).
_STORY_CACHE_TTL_SECONDS = 3600 * 24 * 365
_STORY_MODEL = "claude-haiku-4-5"
# Haiku 4.5는 동적 필터링이 되는 web_search_20260209를 지원하지 않는 모델 목록에
# 있어 기본형(web_search_20250305)을 쓴다 — claude-api 스킬 Server Tools 표 참고.
_STORY_SYSTEM_PROMPT = """당신은 "옛길" 앱에서 특정 동네의 "그 시절" 이야기를 들려주는 리서처입니다.
웹 검색 도구로 이 지역에 관한 실제 기록(뉴스, 역사, 변화상)을 찾아 자연스러운 글로 정리합니다.

규칙:
- 1990년대 → 2000년대 → 2010년대 → 최근 순서로 검색해보고, 특정 연대에 검색되는
  내용이 부족하면 조용히 다음 연대로 넘어갑니다. 모든 연대를 다 채우려 하지 않아도 됩니다.
- 실제로 검색해서 찾은 내용만 사용합니다. 확실하지 않은 내용을 지어내지 않습니다.
- 검색 결과가 이 지역과 직접 관련이 없으면(동명이인 지역 등) 쓰지 않습니다.
- 결과는 2~4문단의 자연스러운 한국어 글로 씁니다 — 목록이나 소제목 없이 이야기하듯 씁니다.
- 글 마지막 줄에 "(출처: ...)" 형식으로 참고한 출처를 한두 개 짧게 남깁니다.
- "검색해보겠습니다", "찾아보겠습니다" 같은 검색 과정 안내 문장을 쓰지 않습니다 —
  검색 도구 호출 전후로 어떤 텍스트도 남기지 말고, 완성된 이야기 글 하나만 답합니다.
- 관련된 내용을 전혀 찾지 못했으면 다른 말 없이 정확히 "NOT_FOUND"라고만 답합니다."""

# 큐레이션한 "그 시절" 목 뉴스 — NAVER 키가 없거나 API 실패 시 폴백.
#
# NOTE(제품 결정, 2026-09-07): 네이버 뉴스 검색 API는 최신 기사만 검색되고, 1990년대~2000년대
# 지역 신문 아카이브를 제공하는 공개 API는 없다(빅카인즈는 유료). 그래서 "그 시절 뉴스" UI
# 라벨은 그대로 두되, 실제로는 그 지역 관련 "최근" 뉴스를 채워 넣기로 결정했다.
# 과거 아카이브 연동은 추후 별도로 검토한다.
_MOCK_NEWS: dict[str, list[NewsItemResponse]] = {
    "suncheon-jeonpo": [
        NewsItemResponse(
            id="n1", year=1998, title="순천 저전동, 신설 초등학교 개교",
            source="전남매일", summary="학생 수 증가에 따라 저전동에 새 초등학교가 문을 열었다.",
        ),
        NewsItemResponse(
            id="n2", year=2004, title="저전동 골목시장 활성화 사업 추진",
            source="순천신문", summary="지역 상인회를 중심으로 골목시장 환경 개선 사업이 시작됐다.",
        ),
        NewsItemResponse(
            id="n3", year=2015, title="저전동 재개발 논의 본격화",
            source="순천신문", summary="노후 주택가 재개발을 위한 주민 설명회가 열렸다.",
        ),
    ],
    "gunsan-jungang": [
        NewsItemResponse(
            id="n4", year=2003, title="군산 중앙로 상권, 주말 유동인구 최대",
            source="군산일보", summary="중앙로 일대 상가에 주말마다 학생들이 몰리며 상권이 활기를 띠었다.",
        ),
    ],
    # 콜드스팟 예시: 뉴스 아카이브가 비어있어 빈 상태 폴백을 확인할 수 있다.
    "yeongwol-jang": [],
}

class ArchiveService:
    """장소별 뉴스 아카이브 서비스. NAVER_NEWS 키가 있으면 실제 검색 결과를,
    없거나 실패하면 큐레이션 목 데이터를 반환한다."""

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
            self._client = Anthropic(api_key=settings.anthropic_api_key, timeout=15, max_retries=0)
        return self._client

    async def get_region_story(self, location_id: str) -> RegionStoryResponse | None:
        """웹 검색으로 찾은 실제 기록을 Claude가 자연어로 종합한 "그 시절" 이야기.

        네이버 뉴스 검색은 최신 기사만 걸리고 1990~2000년대 지역 아카이브를 주는
        무료 API가 없어(get_news_by_location 위 NOTE 참고) 대신 Claude의 웹 검색
        도구로 그때그때 찾게 한다. 과거 기록은 안 바뀌므로 지역당 한 번만 찾고
        사실상 영구(1년) 캐싱한다.
        """
        location = await self._tour_api_service.get_location_by_id(location_id)
        if location is None:
            return None

        query = simplify_place_name(location.region, location.name)
        cache_key = f"regionstory:v2:{query}"

        cached = await cache_get(cache_key)
        if cached is not None:
            return RegionStoryResponse.model_validate(json.loads(cached)) if cached != "null" else None

        story = await self._generate_story(query)
        await cache_set(
            cache_key, story.model_dump_json() if story else "null", ex=_STORY_CACHE_TTL_SECONDS if story else 60
        )
        return story

    async def _generate_story(self, query: str) -> RegionStoryResponse | None:
        client = self._get_client()
        if client is None:
            return None

        try:
            response = await asyncio.to_thread(client.messages.create,
                model=_STORY_MODEL,
                max_tokens=3000,
                system=_STORY_SYSTEM_PROMPT,
                tools=[{"type": "web_search_20250305", "name": "web_search", "max_uses": 5}],
                messages=[{"role": "user", "content": f"지역: {query}"}],
            )
        except APIError:
            logger.exception("Claude region story generation failed for query=%s", query)
            return None

        text = self._extract_final_text(response.content)
        if not text or "NOT_FOUND" in text:
            return None

        return RegionStoryResponse(summary=text)

    @staticmethod
    def _extract_final_text(content: list) -> str:
        """검색을 여러 번 하는 동안 텍스트 블록이 여러 개로 쪼개져 나온다 — 검색
        도중에 쓴 "~검색해보겠습니다" 같은 중간 서술도 섞여 있고(프롬프트로 막아도
        실측으로 새는 걸 확인), 진짜 답변 자체도 검색 사이사이에 나뉘어 오기도 한다.

        마지막 검색 결과(tool_result) 블록 "이후"에 나온 텍스트 블록들만 모으면
        더 이상 검색으로 끊기지 않는 최종 답변만 남는다 — 그 앞은 전부 검색 중
        중간 서술이라 버린다.
        """
        last_tool_result_index = max(
            (i for i, block in enumerate(content) if block.type.endswith("_tool_result")),
            default=-1,
        )
        final_blocks = content[last_tool_result_index + 1 :]
        return " ".join(block.text for block in final_blocks if block.type == "text").strip()

    async def get_news_by_location(self, location_id: str) -> list[NewsItemResponse]:
        if not settings.naver_news_client_id or not settings.naver_news_client_secret:
            return self._mock_for(location_id)

        location = await self._tour_api_service.get_location_by_id(location_id)
        if location is None:
            return self._mock_for(location_id)

        query = simplify_place_name(location.region, location.name)
        items = await self._search_news(query)
        if not items:
            return self._mock_for(location_id)

        return self._sorted(items)

    @staticmethod
    def _sort_key(item: NewsItemResponse) -> str:
        # 연도만 아는 큐레이션 목 데이터는 그 해 1월 1일로 취급해 정렬한다.
        return item.published_at or f"{item.year}-01-01"

    def _sorted(self, items: list[NewsItemResponse]) -> list[NewsItemResponse]:
        return sorted(items, key=self._sort_key)

    def _mock_for(self, location_id: str) -> list[NewsItemResponse]:
        return self._sorted(_MOCK_NEWS.get(location_id, []))

    async def _search_news(self, query: str) -> list[NewsItemResponse]:
        cache_key = f"news:{query}"

        cached = await cache_get(cache_key)
        if cached is not None:
            return [NewsItemResponse.model_validate(item) for item in json.loads(cached)]

        items = await self._fetch_from_naver(query)
        await cache_set(
            cache_key, json.dumps([item.model_dump() for item in items]), ex=_CACHE_TTL_SECONDS
        )

        return items

    async def _fetch_from_naver(self, query: str) -> list[NewsItemResponse]:
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                response = await client.get(
                    "https://openapi.naver.com/v1/search/news.json",
                    headers={
                        "X-Naver-Client-Id": settings.naver_news_client_id,
                        "X-Naver-Client-Secret": settings.naver_news_client_secret,
                    },
                    params={"query": query, "display": 5, "sort": "sim"},
                )
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            logger.exception("Naver News search failed for query=%s", query)
            return []

        results: list[NewsItemResponse] = []
        for raw in body.get("items", []):
            try:
                pub_date = parsedate_to_datetime(raw["pubDate"])
                year = pub_date.year
            except (KeyError, ValueError, TypeError):
                continue

            link = raw.get("originallink") or raw.get("link") or ""
            source = urlparse(link).netloc.removeprefix("www.") or "네이버 뉴스"

            results.append(
                NewsItemResponse(
                    id=hashlib.sha1(link.encode()).hexdigest()[:12] if link else raw["title"][:12],
                    year=year,
                    title=strip_html(raw.get("title", "")),
                    source=source,
                    summary=strip_html(raw.get("description", "")),
                    published_at=pub_date.date().isoformat(),
                    url=link or None,
                )
            )

        return results
