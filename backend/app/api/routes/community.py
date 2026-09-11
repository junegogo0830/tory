from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.community import (
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


@router.get("/posts", response_model=list[CommunityPostResponse])
async def list_posts(
    region: str, limit: int = 20, offset: int = 0, db: AsyncSession = Depends(get_db_session)
) -> list[CommunityPostResponse]:
    return await _community_service.list_posts(db, region=region, limit=limit, offset=offset)


@router.post("/posts", response_model=CommunityPostResponse)
async def create_post(
    region: str = Form(...),
    location_id: str | None = Form(None),
    caption: str | None = Form(None),
    memory_year: int | None = Form(None),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> CommunityPostResponse:
    return await _community_service.create_post(
        db,
        user,
        region=region,
        file=file,
        location_id=location_id,
        caption=caption,
        memory_year=memory_year,
    )
