from fastapi import APIRouter

from ...models.highlight import HighlightCardResponse
from ...services.highlight import HighlightService

router = APIRouter(prefix="/api/highlights", tags=["highlights"])
_highlight_service = HighlightService()


@router.get("", response_model=list[HighlightCardResponse])
async def get_highlight_cards() -> list[HighlightCardResponse]:
    """홈 화면 카드 캐러셀용 랜덤 10장. TourAPI 키가 없으면 빈 리스트."""
    return await _highlight_service.get_highlight_cards()
