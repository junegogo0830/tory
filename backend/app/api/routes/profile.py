from fastapi import APIRouter, Depends, File, Query, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.course import CourseResponse
from ...models.profile import MyMemoryResponse, NicknameUpdateRequest, ProfileResponse
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


@router.get("/memories", response_model=list[MyMemoryResponse])
async def get_memories(
    limit: int = Query(30, ge=1, le=50),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[MyMemoryResponse]:
    return await _profile_service.get_memories(db, user, limit=limit, offset=offset)


@router.get("/courses", response_model=list[CourseResponse])
async def get_my_courses(
    limit: int = Query(30, ge=1, le=50),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[CourseResponse]:
    return await _profile_service.get_my_courses(db, user, limit=limit, offset=offset)


@router.patch("/nickname", response_model=ProfileResponse)
async def update_nickname(
    body: NicknameUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ProfileResponse:
    user = await _profile_service.update_nickname(db, user, body.nickname)
    return await _profile_service.get_profile(db, user)


@router.post("/photo", response_model=ProfileResponse)
async def update_photo(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ProfileResponse:
    user = await _profile_service.update_photo(db, user, file)
    return await _profile_service.get_profile(db, user)


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> None:
    """회원 탈퇴 — 옛길 자체 계정과 관련 데이터를 전부 지운다."""
    await _profile_service.delete_account(db, user)
