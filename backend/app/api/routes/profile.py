from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.profile import ProfileResponse
from ...services.profile import ProfileService
from ..deps import get_current_user

router = APIRouter(prefix="/api/profile", tags=["profile"])
_profile_service = ProfileService()


@router.get("", response_model=ProfileResponse)
async def get_profile(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> ProfileResponse:
    return await _profile_service.get_profile(db, user)


@router.post("/saved-locations/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
async def save_location(
    location_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> None:
    await _profile_service.save_location(db, user, location_id)


@router.delete("/saved-locations/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unsave_location(
    location_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> None:
    await _profile_service.unsave_location(db, user, location_id)


@router.post("/completed-courses/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
async def complete_course(
    course_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> None:
    await _profile_service.complete_course(db, user, course_id)
