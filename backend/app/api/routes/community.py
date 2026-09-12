from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.community import (
    COMMUNITY_BOARDS,
    CommunityPostResponse,
    HomeRegionRequest,
    HomeRegionResponse,
    RegionByCoordsResponse,
)
from ...services.community import CommunityService
from ..deps import get_current_user

router = APIRouter(prefix="/api/community", tags=["community"])
_community_service = CommunityService()


@router.get("/region-by-coords", response_model=RegionByCoordsResponse)
async def get_region_by_coords(lat: float, lng: float) -> RegionByCoordsResponse:
    region = await _community_service.region_by_coords(lat, lng)
    return RegionByCoordsResponse(region=region)


@router.patch("/home-region", response_model=HomeRegionResponse)
async def set_home_region(
    body: HomeRegionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> HomeRegionResponse:
    await _community_service.set_home_region(db, user, body.region)
    return HomeRegionResponse(region=user.home_region)


def _validate_board(board: str) -> None:
    if board not in COMMUNITY_BOARDS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"알 수 없는 게시판이에요: {board}")


@router.get("/posts", response_model=list[CommunityPostResponse])
async def list_posts(
    region: str,
    board: str,
    limit: int = 20,
    offset: int = 0,
    db: AsyncSession = Depends(get_db_session),
) -> list[CommunityPostResponse]:
    _validate_board(board)
    return await _community_service.list_posts(db, region=region, board=board, limit=limit, offset=offset)


@router.post("/posts", response_model=CommunityPostResponse)
async def create_post(
    region: str = Form(...),
    board: str = Form(...),
    title: str | None = Form(None),
    location_id: str | None = Form(None),
    caption: str | None = Form(None),
    memory_year: int | None = Form(None),
    file: UploadFile | None = File(None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> CommunityPostResponse:
    _validate_board(board)
    return await _community_service.create_post(
        db,
        user,
        region=region,
        board=board,
        file=file,
        title=title,
        location_id=location_id,
        caption=caption,
        memory_year=memory_year,
    )
