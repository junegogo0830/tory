from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status, Query
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.community import (
    COMMUNITY_BOARDS,
    BlockedUserResponse,
    CommunityPostResponse,
    HomeRegionRequest,
    HomeRegionResponse,
    NeighborResponse,
    ReportRequest,
    RegionByCoordsResponse,
)
from ...services.community import CommunityService
from ..deps import get_current_user, get_optional_user
from ...models.community import PostDetailResponse, CommentRequest, CommentResponse, PostUpdateRequest

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
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    query: str = Query("", max_length=100),
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[CommunityPostResponse]:
    _validate_board(board)
    return await _community_service.list_posts(
        db,
        region=region,
        board=board,
        limit=limit,
        offset=offset,
        viewer_id=user.id if user else None,
        **({"query": query.strip()} if query.strip() else {}),
    )


@router.post("/posts", response_model=CommunityPostResponse)
async def create_post(
    region: str = Form(...),
    board: str = Form(...),
    title: str | None = Form(None),
    location_id: str | None = Form(None),
    caption: str | None = Form(None),
    memory_year: int | None = Form(None),
    files: list[UploadFile] = File(default_factory=list),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> CommunityPostResponse:
    _validate_board(board)
    return await _community_service.create_post(
        db,
        user,
        region=region,
        board=board,
        files=files,
        title=title,
        location_id=location_id,
        caption=caption,
        memory_year=memory_year,
    )


@router.get('/posts/{post_id}', response_model=PostDetailResponse)
async def detail(post_id: int, user=Depends(get_optional_user), db=Depends(get_db_session)):
    return await _community_service.detail(db, post_id, user)


@router.patch('/posts/{post_id}', response_model=PostDetailResponse)
async def update_post(post_id: int, body: PostUpdateRequest, user=Depends(get_current_user), db=Depends(get_db_session)):
    return await _community_service.update(db, post_id, user, body)


@router.delete('/posts/{post_id}', status_code=204)
async def delete_post(post_id: int, user=Depends(get_current_user), db=Depends(get_db_session)):
    await _community_service.remove(db, post_id, user)


@router.get('/posts/{post_id}/comments', response_model=list[CommentResponse])
async def comments(post_id: int, offset: int = Query(0, ge=0), user=Depends(get_optional_user), db=Depends(get_db_session)):
    return await _community_service.comments(db, post_id, user, offset)


@router.post('/posts/{post_id}/comments', response_model=CommentResponse, status_code=201)
async def add_comment(post_id: int, body: CommentRequest, user=Depends(get_current_user), db=Depends(get_db_session)):
    return await _community_service.add_comment(db, post_id, user, body.body, parent_id=body.parent_id)


@router.delete('/posts/{post_id}/comments/{comment_id}', status_code=204)
async def delete_comment(post_id: int, comment_id: int, user=Depends(get_current_user), db=Depends(get_db_session)):
    await _community_service.remove_comment(db, post_id, comment_id, user)


@router.put('/posts/{post_id}/like', response_model=PostDetailResponse)
async def like(post_id: int, user=Depends(get_current_user), db=Depends(get_db_session)):
    return await _community_service.like(db, post_id, user, True)


@router.delete('/posts/{post_id}/like', response_model=PostDetailResponse)
async def unlike(post_id: int, user=Depends(get_current_user), db=Depends(get_db_session)):
    return await _community_service.like(db, post_id, user, False)


@router.post('/posts/{post_id}/report', status_code=204)
async def report_post(post_id: int, body: ReportRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)):
    await _community_service.report(db, user, target_type="post", target_id=post_id, reason=body.reason)


@router.post('/posts/{post_id}/comments/{comment_id}/report', status_code=204)
async def report_comment(post_id: int, comment_id: int, body: ReportRequest, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)):
    await _community_service.report(db, user, target_type="comment", target_id=comment_id, reason=body.reason)


@router.post('/users/{blocked_user_id}/block', status_code=204)
async def block_user(blocked_user_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)):
    await _community_service.block(db, user, blocked_user_id)


@router.delete('/users/{blocked_user_id}/block', status_code=204)
async def unblock_user(blocked_user_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)):
    await _community_service.unblock(db, user, blocked_user_id)


@router.get('/blocked-users', response_model=list[BlockedUserResponse])
async def blocked_users(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)) -> list[BlockedUserResponse]:
    return await _community_service.list_blocked(db, user)


@router.get('/neighbors', response_model=list[NeighborResponse])
async def neighbors(region: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)) -> list[NeighborResponse]:
    return await _community_service.neighbors(db, user, region=region)


@router.get('/users/{author_id}/posts', response_model=list[CommunityPostResponse])
async def posts_by_user(
    author_id: int,
    region: str,
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[CommunityPostResponse]:
    return await _community_service.list_posts_by_user(
        db, author_id=author_id, region=region, limit=limit, offset=offset, viewer_id=user.id if user else None
    )
