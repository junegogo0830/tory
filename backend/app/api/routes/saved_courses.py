from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.profile import SavedCourseCreateRequest, SavedCourseResponse
from ...services.profile import ProfileService
from ..deps import get_current_user

router = APIRouter(prefix="/api/saved-courses", tags=["saved-courses"])
_service = ProfileService()


@router.post("", status_code=status.HTTP_204_NO_CONTENT)
async def save_course(
    body: SavedCourseCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> None:
    await _service.save_course(db, user, body.course_type, body.course_id)


@router.delete("/{course_type}/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unsave_course(
    course_type: str,
    course_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> None:
    await _service.unsave_course(db, user, course_type, course_id)


@router.get("/status")
async def course_save_status(
    course_type: str = Query(..., pattern="^(generated|custom)$"),
    course_id: str = Query(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, bool]:
    saved = await _service.is_course_saved(db, user, course_type, course_id)
    return {"saved": saved}


@router.get("", response_model=list[SavedCourseResponse])
async def list_saved_courses(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> list[SavedCourseResponse]:
    return await _service.list_saved_courses(db, user)
