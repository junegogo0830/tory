from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ...db.models import User
from ...db.postgres import get_db_session
from ...models.memory import (
    MemoryAttributeCreateRequest,
    MemoryAttributeResponse,
    MemoryMatchResponse,
    MemoryProfileResponse,
    MemorySearchRequest,
)
from ...services.memory_profile import MemoryProfileService
from ..deps import get_current_user, get_optional_user

router = APIRouter(prefix="/api/memory", tags=["memory"])
_service = MemoryProfileService()


@router.post("/attributes", response_model=MemoryAttributeResponse)
async def add_memory_attribute(
    body: MemoryAttributeCreateRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> MemoryAttributeResponse:
    return await _service.add_attribute(db, user, body)


@router.get("/attributes/me", response_model=list[MemoryAttributeResponse])
async def list_my_memory_attributes(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[MemoryAttributeResponse]:
    return await _service.list_attributes(db, user.id)


@router.delete("/attributes/{attribute_id}", status_code=204)
async def delete_memory_attribute(
    attribute_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> None:
    await _service.delete_attribute(db, user, attribute_id)


@router.post("/search", response_model=list[MemoryMatchResponse])
async def search_memory_matches(
    body: MemorySearchRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> list[MemoryMatchResponse]:
    return await _service.search_matches(db, user, body.filters)


@router.get("/profile/{user_id}", response_model=MemoryProfileResponse)
async def get_memory_profile(
    user_id: int,
    viewer: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db_session),
) -> MemoryProfileResponse:
    return await _service.get_profile(db, viewer, user_id)
