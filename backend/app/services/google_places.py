import logging
from urllib.parse import urlencode

import httpx

from ..core.config import settings
from ..db.redis import cache_get, cache_set

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 3600 * 24


class GooglePlacesService:
    """TourAPI(대표사진 + 사진갤러리)에도 사진이 없는 장소를 위한 최후 보강 소스.

    소규모 식당·카페는 관광공사 TourAPI에 사진이 아예 등록 안 된 경우가 많은데,
    구글 지도는 사용자 제보 사진이 이런 곳도 잘 커버한다. Find Place로 장소를
    찾고, 그 사진의 실제 CDN URL(googleusercontent.com)을 한 번 리다이렉트를
    따라가 확인해 캐싱한다 — 그래야 프론트가 매번 이 API를 다시 안 거치고
    바로 이미지를 띄울 수 있다.
    """

    def __init__(self) -> None:
        self._base_url = "https://maps.googleapis.com/maps/api/place"

    async def find_photo(self, name: str, region: str | None = None) -> str | None:
        if not settings.google_maps_api_key:
            return None

        query = f"{region} {name}" if region else name
        cache_key = f"gplacephoto:{query}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return cached or None

        photo_url = await self._lookup(query)
        await cache_set(cache_key, photo_url or "", ex=_CACHE_TTL_SECONDS)
        return photo_url

    async def _lookup(self, query: str) -> str | None:
        params = {
            "input": query,
            "inputtype": "textquery",
            "fields": "photos",
            "key": settings.google_maps_api_key,
        }
        url = f"{self._base_url}/findplacefromtext/json?{urlencode(params)}"
        try:
            async with httpx.AsyncClient(timeout=8) as client:
                response = await client.get(url)
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            logger.exception("Google Places lookup failed for query=%s", query)
            return None

        candidates = body.get("candidates", [])
        if not candidates:
            return None
        photos = candidates[0].get("photos", [])
        if not photos:
            return None
        photo_reference = photos[0].get("photo_reference")
        if not photo_reference:
            return None

        return await self._resolve_photo_url(photo_reference)

    async def _resolve_photo_url(self, photo_reference: str) -> str | None:
        """Place Photo 엔드포인트는 실제 이미지로 302 리다이렉트한다 — 그 Location
        헤더(googleusercontent.com 고정 URL)만 뽑아서 저장하면, 이후엔 API 키 없이도
        바로 이미지를 띄울 수 있고 매 조회마다 과금되지도 않는다."""
        params = {
            "maxwidth": 800,
            "photo_reference": photo_reference,
            "key": settings.google_maps_api_key,
        }
        url = f"{self._base_url}/photo?{urlencode(params)}"
        try:
            async with httpx.AsyncClient(timeout=8, follow_redirects=False) as client:
                response = await client.get(url)
        except httpx.HTTPError:
            logger.exception("Google Places photo redirect resolution failed")
            return None

        if response.status_code in (301, 302) and "location" in response.headers:
            return response.headers["location"]
        return None
