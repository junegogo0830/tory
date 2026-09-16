from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.auth import PasswordChangeRequest
from ...models.course import CourseResponse
from ...models.profile import (
    MyMemoryResponse,
    NicknameUpdateRequest,
    OnboardingRequest,
    ProfileInfoUpdateRequest,
    ProfileResponse,
    RecentCourseResponse,
    RecordCourseViewRequest,
)
from ...services.auth import AuthService
from ...services.profile import ProfileService
from ..deps import get_current_user

router = APIRouter(prefix="/api/profile", tags=["profile"])
_profile_service = ProfileService()
_auth_service = AuthService()


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


@router.get("/recent-course", response_model=RecentCourseResponse | None)
async def get_recent_course(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> RecentCourseResponse | None:
    """홈 "이어보기" 카드 — 마지막으로 열어본 코스가 없으면 null."""
    return await _profile_service.get_recent_course(db, user)


@router.put("/recent-course", status_code=status.HTTP_204_NO_CONTENT)
async def record_course_view(
    body: RecordCourseViewRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> None:
    """코스 상세 화면을 열 때마다 호출 — 마지막으로 본 코스를 덮어쓴다."""
    await _profile_service.record_course_view(db, user, body.course_type, body.course_id)


@router.patch("/onboarding", response_model=ProfileResponse)
async def complete_onboarding(
    body: OnboardingRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ProfileResponse:
    """완료든 건너뛰기든 이 엔드포인트를 호출하면 이 사용자에게 다시 온보딩
    화면이 뜨지 않는다. 거주지/살았던 곳은 이미 있는 community/saved-locations
    엔드포인트를 프론트가 따로 호출한다."""
    user = await _profile_service.complete_onboarding(db, user, body.age_group)
    return await _profile_service.get_profile(db, user)


@router.patch("/nickname", response_model=ProfileResponse)
async def update_nickname(
    body: NicknameUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ProfileResponse:
    user = await _profile_service.update_nickname(db, user, body.nickname)
    return await _profile_service.get_profile(db, user)


@router.patch("/info", response_model=ProfileResponse)
async def update_info(
    body: ProfileInfoUpdateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ProfileResponse:
    """"정보 수정" 화면 — 성별/이름/전화번호. 나이·사는 곳은 기존 onboarding/
    community 엔드포인트를, 모교·살았던 곳은 /api/memory/attributes를 그대로 쓴다."""
    user = await _profile_service.update_info(db, user, body)
    return await _profile_service.get_profile(db, user)


@router.post("/photo", response_model=ProfileResponse)
async def update_photo(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> ProfileResponse:
    user = await _profile_service.update_photo(db, user, file)
    return await _profile_service.get_profile(db, user)


@router.patch("/password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    body: PasswordChangeRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> None:
    """자체 회원가입(아이디+비밀번호) 계정만 가능 — 카카오 로그인 계정은 422."""
    try:
        await _auth_service.change_password(db, user, body.current_password, body.new_password)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db_session)
) -> None:
    """회원 탈퇴 — 옛길 자체 계정과 관련 데이터를 전부 지운다."""
    await _profile_service.delete_account(db, user)
