import asyncio
import json
import logging
import random

from ..db.redis import cache_get, cache_set
from ..models.highlight import HighlightCardResponse
from .tourapi import TourApiService

logger = logging.getLogger(__name__)

_POOL_CACHE_KEY = "highlightpool"
_POOL_CACHE_TTL_SECONDS = 3600 * 24 * 7  # 풀은 일주일에 한 번만 다시 만든다.
_CARDS_PER_REQUEST = 10

# TourAPI에 "루트"라는 멀티스탑 개념은 없다 — 실제로 있는 건 "장소" 단위 데이터라,
# 지역을 대표하는 키워드로 반복 검색해 사진 있는 장소 ~30개 풀을 구성한다.
_SEED_KEYWORDS = [
    "서울", "부산", "전주", "경주", "강릉", "순천", "여수", "군산", "제주", "통영",
]
_RESULTS_PER_KEYWORD = 4


class HighlightService:
    """홈 화면 카드 캐러셀용 "혜택카드"st 풀. TourAPI 실제 장소 데이터로 ~30개
    풀을 만들어 일주일 캐싱하고, 요청마다 그중 10개를 무작위로 골라준다."""

    def __init__(self, tour_api_service: TourApiService | None = None) -> None:
        self._tour_api_service = tour_api_service or TourApiService()

    async def get_highlight_cards(self) -> list[HighlightCardResponse]:
        pool = await self._get_pool()
        if not pool:
            return []
        return random.sample(pool, min(_CARDS_PER_REQUEST, len(pool)))

    async def _get_pool(self) -> list[HighlightCardResponse]:
        cached = await cache_get(_POOL_CACHE_KEY)
        if cached is not None:
            return [HighlightCardResponse.model_validate(item) for item in json.loads(cached)]

        pool = await self._build_pool()
        await cache_set(
            _POOL_CACHE_KEY,
            json.dumps([card.model_dump() for card in pool]),
            ex=_POOL_CACHE_TTL_SECONDS,
        )
        return pool

    async def _build_pool(self) -> list[HighlightCardResponse]:
        results = await asyncio.gather(
            *(
                self._tour_api_service.search_attractions(keyword, _RESULTS_PER_KEYWORD)
                for keyword in _SEED_KEYWORDS
            )
        )

        pool: list[HighlightCardResponse] = []
        seen_ids: set[str] = set()
        for locations in results:
            for location in locations:
                if location.image_url is None or location.id in seen_ids:
                    continue
                seen_ids.add(location.id)
                pool.append(
                    HighlightCardResponse(
                        id=location.id,
                        title=location.name,
                        region=location.region,
                        image_url=location.image_url,
                        category="관광지",
                    )
                )

        if not pool:
            logger.warning("Highlight pool build returned no results (TOUR_API_KEY missing?)")
        return pool
