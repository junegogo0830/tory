import asyncio
import json
import logging
import re
from urllib.parse import urlencode

import httpx

from ..core.config import settings
from ..db.redis import cache_get, cache_set

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 3600 * 24

# Nearby Search에서 "가볼 만한 곳"으로 인정할 카테고리만 허용한다(화이트리스트) —
# 필터 없이 쓰면 옷가게·은행·마트 같은 일반 업체까지 섞여 들어온다. "point_of_
# interest"/"establishment"는 구글이 거의 모든 장소에 함께 붙이는 너무 넓은
# 상위 타입이라 일부러 뺐다 — 넣으면 화이트리스트가 사실상 무력화된다.
_ALLOWED_TYPES = {
    "tourist_attraction", "park", "museum", "cafe", "restaurant", "bakery",
    "art_gallery", "place_of_worship", "zoo", "aquarium", "amusement_park",
    "natural_feature",
}

_ATTRIBUTION_RE = re.compile(r'<a href="([^"]+)"[^>]*>([^<]+)</a>')


def _parse_attribution(html_attributions: list[str]) -> dict | None:
    """구글 Places 사진에 딸려오는 "<a href=...>기여자명</a>" HTML에서
    이름/링크만 뽑는다. 구글 이용약관상 이 사진을 화면에 보여주려면 이
    출처 표기를 같이 보여줘야 한다 — image_url만 뽑고 버리면 안 된다."""
    if not html_attributions:
        return None
    match = _ATTRIBUTION_RE.search(html_attributions[0])
    if not match:
        return None
    return {"attribution_url": match.group(1), "attribution_name": match.group(2)}


class GooglePlacesService:
    """TourAPI(대표사진 + 사진갤러리)에도 사진이 없는 장소를 위한 최후 보강 소스.

    소규모 식당·카페는 관광공사 TourAPI에 사진이 아예 등록 안 된 경우가 많은데,
    구글 지도는 사용자 제보 사진이 이런 곳도 잘 커버한다. Find Place로 장소를
    찾고, 그 사진의 실제 CDN URL(googleusercontent.com)을 한 번 리다이렉트를
    따라가 확인해 캐싱한다 — 그래야 프론트가 매번 이 API를 다시 안 거치고
    바로 이미지를 띄울 수 있다.

    반환값에는 항상 image_url과 함께 attribution_name/attribution_url을
    같이 담는다 — 구글 Places 사진 표시 시 기여자 출처 표기가 이용약관상
    필수라, 호출부(course_generator.py 등)가 화면에 같이 보여줘야 한다.
    """

    def __init__(self) -> None:
        self._base_url = "https://maps.googleapis.com/maps/api/place"

    async def find_photo(self, name: str, region: str | None = None) -> dict | None:
        """{"image_url", "attribution_name", "attribution_url"} 또는 None."""
        if not settings.google_maps_api_key:
            return None

        query = f"{region} {name}" if region else name
        cache_key = f"gplacephoto:v3:{query}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return json.loads(cached) if cached != "" else None

        result = await self._lookup(query)
        await cache_set(cache_key, json.dumps(result) if result else "", ex=_CACHE_TTL_SECONDS)
        return result

    async def _lookup(self, query: str) -> dict | None:
        params = {
            "input": query,
            "inputtype": "textquery",
            "fields": "photos",
            "language": "ko",
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
        return await self._to_photo_result(photos[0])

    async def find_nearby(
        self, *, latitude: float, longitude: float, radius_m: int = 3000, num_rows: int = 10
    ) -> list[dict]:
        """좌표 반경 내 "가볼 만한 곳" 실제 장소를 이름·좌표·사진과 함께 찾는다 —
        find_photo(이름으로 사진 한 장만 찾기)와 달리 후보 자체를 새로 발굴하는 용도다.

        CourseGeneratorService가 관광사진 정보 API만으로 후보가 2곳도 안 모일 때
        (사진 갤러리 커버리지가 얕은 지역) 후보 풀을 보강하기 위해 쓴다. 사진이
        없는 결과와, _ALLOWED_TYPES에 없는 카테고리(옷가게·은행·마트 등 일반
        업체)는 애초에 버린다.
        """
        if not settings.google_maps_api_key:
            return []

        # v6: 카테고리별 세부 필터링(CoursePlanner)을 위해 raw types도 함께 담는다.
        cache_key = f"gplacenearby:v6:{round(latitude, 3)}:{round(longitude, 3)}:{radius_m}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return json.loads(cached)

        params = {
            "location": f"{latitude},{longitude}",
            "radius": radius_m,
            "language": "ko",
            "key": settings.google_maps_api_key,
        }
        url = f"{self._base_url}/nearbysearch/json?{urlencode(params)}"
        try:
            async with httpx.AsyncClient(timeout=8) as client:
                response = await client.get(url)
                response.raise_for_status()
                body = response.json()
        except (httpx.HTTPError, ValueError):
            logger.exception("Google Places nearby search failed for (%s, %s)", latitude, longitude)
            return []

        results = [
            r for r in body.get("results", [])
            if r.get("name") and r.get("photos") and (_ALLOWED_TYPES & set(r.get("types", [])))
        ][:num_rows]

        async def to_candidate(result: dict) -> dict | None:
            photo = await self._to_photo_result(result["photos"][0])
            if photo is None:
                return None
            loc = result.get("geometry", {}).get("location", {})
            if loc.get("lat") is None or loc.get("lng") is None:
                return None
            return {
                "title": result["name"],
                "latitude": loc["lat"],
                "longitude": loc["lng"],
                "address": result.get("vicinity", ""),
                "types": result.get("types", []),
                **photo,
            }

        resolved = await asyncio.gather(*(to_candidate(r) for r in results))
        candidates = [c for c in resolved if c is not None]

        await cache_set(cache_key, json.dumps(candidates), ex=_CACHE_TTL_SECONDS)
        return candidates

    async def _to_photo_result(self, photo: dict) -> dict | None:
        photo_reference = photo.get("photo_reference")
        if not photo_reference:
            return None
        photo_url = await self._resolve_photo_url(photo_reference)
        if photo_url is None:
            return None
        attribution = _parse_attribution(photo.get("html_attributions", [])) or {}
        return {
            "image_url": photo_url,
            "attribution_name": attribution.get("attribution_name"),
            "attribution_url": attribution.get("attribution_url"),
        }

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
