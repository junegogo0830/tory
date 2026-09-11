from fastapi import APIRouter

from ...models.news import NewsItemResponse, RegionStoryResponse
from ...services.archive import ArchiveService

router = APIRouter(prefix="/api/archive", tags=["archive"])
_archive_service = ArchiveService()


@router.get("/{location_id}", response_model=list[NewsItemResponse])
async def get_news_by_location(location_id: str) -> list[NewsItemResponse]:
    """장소의 그 시절 지역 뉴스 타임라인을 반환한다. 데이터가 없으면 빈 리스트를 반환한다."""
    return await _archive_service.get_news_by_location(location_id)


@router.get("/{location_id}/story", response_model=RegionStoryResponse | None)
async def get_region_story(location_id: str) -> RegionStoryResponse | None:
    """Claude 웹 검색으로 종합한 "그 시절" 이야기. 찾은 게 없으면 null."""
    return await _archive_service.get_region_story(location_id)
