from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.custom_course import (
    CustomCourseCommentRequest,
    CustomCourseCommentResponse,
    CustomCourseCreateRequest,
    CustomCourseResponse,
    CustomCourseSummaryResponse,
    CustomCourseUpdateRequest,
    CustomCourseVoteRequest,
)
from ...models.memory import MemoryOverlapResponse
from ...services.custom_course import CustomCourseService
from ...services.memory_profile import MemoryProfileService
from ..deps import get_current_user, get_optional_user

router = APIRouter(prefix="/api/custom-courses", tags=["custom-course"])
_service = CustomCourseService()
_memory_service = MemoryProfileService()


@router.post("", response_model=CustomCourseResponse)
async def create_custom_course(
    body: CustomCourseCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> CustomCourseResponse:
    return await _service.create(db, user, body)


@router.post("/photos")
async def upload_custom_course_photo(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
) -> dict[str, str]:
    """코스 장소에 직접 등록하는 사진 — 업로드 후 받은 url을 place.image_url로 써서
    코스 생성/수정 요청에 그대로 실어 보낸다."""
    url = await _service.upload_photo(file)
    return {"url": url}


@router.get("", response_model=list[CustomCourseSummaryResponse])
async def list_custom_courses(
    category: str | None = Query(None),
    sort: str = Query("recent", pattern="^(recent|popular)$"),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    # true면 로그인한 내가 만든 코스만 — "코스 공유" 작성 화면에서 "내 코스에서
    # 가져오기" 목록을 채우는 데 쓴다. author_id를 클라이언트가 직접 넘기게
    # 하는 대신 서버가 로그인 사용자로 한정해서, 다른 사람 id를 몰라도 되고
    # 실수로 남의 코스를 요청할 일도 없다.
    mine: bool = Query(False),
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[CustomCourseSummaryResponse]:
    author_id = None
    if mine:
        if user is None:
            raise HTTPException(status_code=401, detail="로그인이 필요해요")
        author_id = user.id
    return await _service.list_courses(
        db, category=category, sort=sort, limit=limit, offset=offset, author_id=author_id
    )


@router.get("/by-author/{author_id}", response_model=list[CustomCourseSummaryResponse])
async def list_custom_courses_by_author(
    author_id: int,
    limit: int = Query(10, ge=1, le=30),
    db: AsyncSession = Depends(get_db_session),
) -> list[CustomCourseSummaryResponse]:
    """추억 프로필에서 그 사람의 공개 코스만 보여준다(비공개 코스는 절대 포함하지 않음)."""
    return await _service.list_public_by_author(db, author_id, limit=limit)


@router.get("/{course_id}", response_model=CustomCourseResponse)
async def get_custom_course(
    course_id: int,
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db_session),
) -> CustomCourseResponse:
    return await _service.detail(db, course_id, user)


@router.patch("/{course_id}", response_model=CustomCourseResponse)
async def update_custom_course(
    course_id: int,
    body: CustomCourseUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> CustomCourseResponse:
    return await _service.update(db, course_id, user, body)


@router.get("/{course_id}/map", response_class=HTMLResponse)
async def get_custom_course_map(course_id: int, db: AsyncSession = Depends(get_db_session)) -> HTMLResponse:
    return HTMLResponse(await _service.render_map(db, course_id))


@router.get("/{course_id}/memory-overlap", response_model=MemoryOverlapResponse)
async def get_custom_course_memory_overlap(
    course_id: int, db: AsyncSession = Depends(get_db_session)
) -> MemoryOverlapResponse:
    course = await _service.require_course(db, course_id)
    matches = await _memory_service.overlap_for_course(db, course)
    return MemoryOverlapResponse(count=len(matches), matches=matches)


@router.delete("/{course_id}", status_code=204)
async def delete_custom_course(
    course_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> None:
    await _service.remove(db, course_id, user)


@router.post("/{course_id}/vote", response_model=CustomCourseResponse)
async def vote_custom_course(
    course_id: int,
    body: CustomCourseVoteRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> CustomCourseResponse:
    return await _service.vote(db, course_id, user, body.value)


@router.get("/{course_id}/comments", response_model=list[CustomCourseCommentResponse])
async def list_custom_course_comments(
    course_id: int,
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[CustomCourseCommentResponse]:
    return await _service.comments(db, course_id, user)


@router.post("/{course_id}/comments", response_model=CustomCourseCommentResponse)
async def add_custom_course_comment(
    course_id: int,
    body: CustomCourseCommentRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> CustomCourseCommentResponse:
    return await _service.add_comment(db, course_id, user, body.body)


@router.delete("/{course_id}/comments/{comment_id}", status_code=204)
async def delete_custom_course_comment(
    course_id: int,
    comment_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> None:
    await _service.remove_comment(db, course_id, comment_id, user)
