import asyncio
import json
import logging
from urllib.parse import urlencode

import httpx

from ..core.config import settings
from ..db.redis import cache_get, cache_set

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 3600 * 24  # 사진 메타데이터는 자주 안 바뀐다.


class PhotoGalleryService:
    """한국관광공사 "관광사진 정보" API(PhotoGalleryService1) 연동.

    국문 관광정보 API(KorService2, tourapi.py)와는 data.go.kr에 완전히 별도로
    등록해야 하는 API다 — firstimage/firstimage2(국문 관광정보의 대표 이미지
    필드)와 절대 혼동하면 안 된다. 이 API는 phoko.visitkorea.or.kr의 약 10만 장
    사진 메타데이터(제목/촬영지/키워드/웹용 이미지 URL)만 제공하고, contentId나
    좌표는 주지 않는다 — 그래서 "이 지역에 실제로 사진이 존재하는 장소가 어디인지"를
    1차로 걸러내는 용도로만 쓰고, 좌표·주소·contentId 등 상세 정보는
    TourApiService(국문 관광정보 API)와 장소명으로 매칭해서 보강한다
    (course_generator.py의 candidate pool 생성 참고).
    """

    def __init__(self) -> None:
        self._base_url = "https://apis.data.go.kr/B551011/PhotoGalleryService1"

    def _service_key(self) -> str:
        # 별도 키가 없으면 같은 data.go.kr 계정의 국문 관광정보 API 키로 대체한다
        # (대부분 한 계정의 활용신청 키가 여러 TourAPI 상품에 공용으로 쓰인다).
        return settings.tour_photo_api_key or settings.tour_api_key

    async def _get(self, path: str, **params: object) -> dict:
        query = urlencode(params)
        url = f"{self._base_url}/{path}?serviceKey={self._service_key()}&{query}"
        last_error: httpx.HTTPError | None = None
        for attempt in range(2):
            try:
                async with httpx.AsyncClient(timeout=8) as client:
                    response = await client.get(url)
                    response.raise_for_status()
                    return response.json()
            except httpx.HTTPError as e:
                last_error = e
                if attempt == 0:
                    await asyncio.sleep(0.5)
        raise last_error

    async def search_photos(self, keyword: str, num_rows: int = 30) -> list[dict]:
        """키워드(지역명/장소명)로 실제 사진이 있는 항목만 반환한다.

        각 항목: {"title": 사진/장소 제목, "image_url": 웹용 이미지 URL,
        "location_text": 촬영 장소 텍스트(자유 텍스트, 좌표 아님)}.
        이 API 자체가 좌표 반경 검색을 지원하지 않으므로, 호출부(course_generator.py)가
        국문 관광정보 API로 후보 각각의 실제 좌표를 다시 확인해 거리를 검증한다.
        """
        if not self._service_key():
            return []

        cache_key = f"photogallery:v1:{keyword}:{num_rows}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return json.loads(cached)

        try:
            body = await self._get(
                "gallerySearchList1",
                keyword=keyword,
                MobileOS="ETC",
                MobileApp="Yetgil",
                _type="json",
                numOfRows=num_rows,
                arrange="C",
            )
        except (httpx.HTTPError, ValueError):
            logger.exception("PhotoGalleryService gallerySearchList1 failed for keyword=%s", keyword)
            return []

        items = body.get("response", {}).get("body", {}).get("items", "")
        item_list = items.get("item", []) if items else []

        results = [
            {
                "title": item.get("galTitle", "").strip(),
                "image_url": item.get("galWebImageUrl") or None,
                "location_text": item.get("galPhotographyLocation", ""),
            }
            for item in item_list
            if item.get("galTitle") and item.get("galWebImageUrl")
        ]

        await cache_set(cache_key, json.dumps(results), ex=_CACHE_TTL_SECONDS)
        return results
