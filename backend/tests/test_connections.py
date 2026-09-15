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
from app.services.connections import ConnectionService

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


@pytest.mark.asyncio
async def test_send_request_rejects_self_and_duplicates(db):
    service = ConnectionService()
    a = User(kakao_id="a", nickname="A")
    b = User(kakao_id="b", nickname="B")
    db.add_all([a, b])
    await db.commit()

    with pytest.raises(HTTPException):
        await service.send_request(db, a, a.id, None)

    request = await service.send_request(db, a, b.id, "혹시 2009년 옛길고 다니셨나요?")
    assert request.status == "pending"

    with pytest.raises(HTTPException):
        await service.send_request(db, a, b.id, "또 보냄")
    with pytest.raises(HTTPException):
        await service.send_request(db, b, a.id, "역방향도 막힘")


@pytest.mark.asyncio
async def test_only_recipient_can_respond_and_accept_unlocks_messages(db):
    service = ConnectionService()
    requester = User(kakao_id="req", nickname="요청자")
    recipient = User(kakao_id="rec", nickname="수신자")
    db.add_all([requester, recipient])
    await db.commit()

    request = await service.send_request(db, requester, recipient.id, "안녕하세요")

    with pytest.raises(HTTPException):
        await service.respond(db, requester, request.id, True)

    with pytest.raises(HTTPException):
        await service.send_message(db, requester, request.id, "아직 안 됨")

    accepted = await service.respond(db, recipient, request.id, True)
    assert accepted.status == "accepted"

    with pytest.raises(HTTPException):
        await service.respond(db, recipient, request.id, True)  # 이미 처리됨

    sent = await service.send_message(db, requester, request.id, "반가워요!")
    assert sent.is_mine is True

    from_recipient_view = await service.list_messages(db, recipient, request.id)
    assert len(from_recipient_view) == 1
    assert from_recipient_view[0].is_mine is False
    assert from_recipient_view[0].body == "반가워요!"

    connections = await service.list_connections(db, requester)
    assert [c.id for c in connections] == [request.id]


@pytest.mark.asyncio
async def test_declined_request_can_be_resent(db):
    service = ConnectionService()
    requester = User(kakao_id="req2", nickname="요청자")
    recipient = User(kakao_id="rec2", nickname="수신자")
    db.add_all([requester, recipient])
    await db.commit()

    request = await service.send_request(db, requester, recipient.id, None)
    declined = await service.respond(db, recipient, request.id, False)
    assert declined.status == "declined"

    resent = await service.send_request(db, requester, recipient.id, "다시 요청해요")
    assert resent.status == "pending"
