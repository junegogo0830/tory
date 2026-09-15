import html

from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ...core.config import settings
from ...db.models import CommunityPost
from ...db.postgres import get_db_session
from ...services.map_html import render_map_page, render_message_page
from ...services.tourapi import TourApiService

router = APIRouter(prefix="/community-map", tags=["community-map"])
_tour_api_service = TourApiService()

_MAX_MARKERS = 100


@router.get("/{region}/{board}", response_class=HTMLResponse)
async def get_community_map_page(
    region: str, board: str, db: AsyncSession = Depends(get_db_session)
) -> HTMLResponse:
    """관광정보 게시판 "지도로 보기" — 장소가 첨부된 글들을 카카오맵 위 마커로
    보여주는 웹뷰 페이지(roadview.py와 같은 패턴: JSON이 아니라 완결된 HTML을
    직접 서빙 — 카카오맵 JS SDK가 로드된 페이지의 도메인을 콘솔 등록 플랫폼과
    대조하기 때문). 마커를 누르면 뜨는 "게시글 보기" 링크는 커스텀 스킴
    (yetgil-post://{post_id})이라 실제로 이동하지 않고, 프론트의
    WebView NavigationDelegate가 가로채 앱 안에서 게시글 상세로 이동시킨다.
    """
    if not settings.kakao_map_js_key:
        return HTMLResponse(render_message_page("카카오맵 키가 설정되지 않았어요"))

    rows = await db.execute(
        select(CommunityPost)
        .where(
            CommunityPost.region == region,
            CommunityPost.board == board,
            CommunityPost.hidden.is_(False),
            CommunityPost.location_id.is_not(None),
        )
        .order_by(CommunityPost.created_at.desc())
        .limit(_MAX_MARKERS)
    )
    posts = rows.scalars().all()

    markers: list[dict] = []
    for post in posts:
        location = await _tour_api_service.get_location_by_id(post.location_id)
        if location is None or location.latitude is None or location.longitude is None:
            continue
        markers.append(
            {
                "lat": location.latitude,
                "lng": location.longitude,
                "title": html.escape(post.title or location.name),
                "place": html.escape(location.name),
                "linkUrl": f"yetgil-post://{post.id}",
            }
        )

    if not markers:
        return HTMLResponse(render_message_page("아직 지도에 표시할 장소가 없어요"))

    return HTMLResponse(render_map_page(markers=markers, js_key=settings.kakao_map_js_key))
