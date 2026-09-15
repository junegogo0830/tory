import json
import os
import uuid

import pytest
import pytest_asyncio
from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings
from app.db.base import Base
from app.db.models import User
from app.services.community import CommunityService

pytestmark = pytest.mark.skipif(os.environ.get("RUN_DB_TESTS") != "1", reason="Requires isolated PostgreSQL schema")


@pytest_asyncio.fixture
async def db():
    schema = "test_" + uuid.uuid4().hex
    admin = create_async_engine(settings.database_url)
    async with admin.begin() as conn:
        await conn.execute(text("CREATE SCHEMA " + schema))
    engine = create_async_engine(settings.database_url, connect_args={"server_settings": {"search_path": schema}})
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with async_sessionmaker(engine, expire_on_commit=False)() as session:
            yield session
    finally:
        await engine.dispose()
        async with admin.begin() as conn:
            await conn.execute(text("DROP SCHEMA " + schema + " CASCADE"))
        await admin.dispose()


class _FakeUploadFile:
    def __init__(self, content: bytes, content_type: str = "image/jpeg", filename: str = "p.jpg") -> None:
        self.content_type = content_type
        self.filename = filename
        self._content = content

    async def read(self, _n: int) -> bytes:
        return self._content


@pytest.mark.asyncio
async def test_content_blocks_resolve_image_index_to_url_and_derive_caption(db):
    service = CommunityService()
    user = User(kakao_id="blocks-user", nickname="나")
    db.add(user)
    await db.commit()

    files = [_FakeUploadFile(b"\xff\xd8\xff" + bytes([i]) * 20) for i in range(2)]
    blocks = json.dumps(
        [
            {"type": "text", "text": "그날 놀이터에서"},
            {"type": "image", "index": 0},
            {"type": "text", "text": "친구들이랑 사진 찍었다"},
            {"type": "image", "index": 1},
        ]
    )
    post = await service.create_post(
        db, user, region="서울 종로구", board="free", title="블록 글", files=files, content_blocks=blocks
    )

    assert post.caption == "그날 놀이터에서\n\n친구들이랑 사진 찍었다"
    assert post.content_blocks is not None
    types = [b.type for b in post.content_blocks]
    assert types == ["text", "image", "text", "image"]
    assert post.content_blocks[1].image_url == post.photo_urls[0]
    assert post.content_blocks[3].image_url == post.photo_urls[1]

    detail = await service.detail(db, post.id, user)
    assert [b.type for b in detail.content_blocks] == ["text", "image", "text", "image"]
    assert detail.content_blocks[1].image_url == post.photo_urls[0]


@pytest.mark.asyncio
async def test_old_style_post_has_no_content_blocks(db):
    service = CommunityService()
    user = User(kakao_id="blocks-user-2", nickname="나")
    db.add(user)
    await db.commit()

    post = await service.create_post(db, user, region="서울 종로구", board="free", title="옛날 글", caption="그냥 캡션")
    assert post.content_blocks is None
    assert post.caption == "그냥 캡션"

    detail = await service.detail(db, post.id, user)
    assert detail.content_blocks is None
    assert detail.caption == "그냥 캡션"


@pytest.mark.asyncio
async def test_content_blocks_reject_invalid_structure(db):
    service = CommunityService()
    user = User(kakao_id="blocks-user-3", nickname="나")
    db.add(user)
    await db.commit()

    with pytest.raises(HTTPException):
        await service.create_post(
            db, user, region="서울 종로구", board="free", title="깨진 블록", content_blocks="not json"
        )

    with pytest.raises(HTTPException):
        await service.create_post(
            db,
            user,
            region="서울 종로구",
            board="free",
            title="없는 사진 참조",
            content_blocks=json.dumps([{"type": "image", "index": 0}]),
        )

    with pytest.raises(HTTPException):
        await service.create_post(
            db,
            user,
            region="서울 종로구",
            board="free",
            title="빈 블록",
            content_blocks=json.dumps([]),
        )
