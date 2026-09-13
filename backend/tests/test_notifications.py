import os
import uuid
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy import text
from app.core.config import settings
from app.db.base import Base
from app.db.models import User
from app.services.community import CommunityService
from app.services.notifications import NotificationService

pytestmark = pytest.mark.skipif(os.environ.get('RUN_DB_TESTS') != '1', reason='Requires isolated PostgreSQL schema')


@pytest_asyncio.fixture
async def db():
    schema = 'test_' + uuid.uuid4().hex
    admin = create_async_engine(settings.database_url)
    async with admin.begin() as conn:
        await conn.execute(text('CREATE SCHEMA ' + schema))
    engine = create_async_engine(settings.database_url, connect_args={'server_settings': {'search_path': schema}})
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with async_sessionmaker(engine, expire_on_commit=False)() as session:
            yield session
    finally:
        await engine.dispose()
        async with admin.begin() as conn:
            await conn.execute(text('DROP SCHEMA ' + schema + ' CASCADE'))
        await admin.dispose()


@pytest.mark.asyncio
async def test_comment_and_like_create_notifications_for_author_only(db):
    community = CommunityService()
    notifications = NotificationService()
    author = User(kakao_id='notif-author', nickname='작성자')
    commenter = User(kakao_id='notif-commenter', nickname='댓글러')
    db.add_all([author, commenter])
    await db.commit()
    post = await community.create_post(db, author, region='서울 종로구', board='free', title='글', caption='내용')

    # 본인 글에 본인이 댓글/좋아요를 달면 알림이 생기지 않는다.
    await community.add_comment(db, post.id, author, '셀프 댓글')
    await community.like(db, post.id, author, True)
    assert await notifications.unread_count(db, author) == 0

    # 남이 댓글/좋아요를 달면 작성자에게 알림이 쌓인다.
    await community.add_comment(db, post.id, commenter, '좋은 글이에요')
    await community.like(db, post.id, commenter, True)
    assert await notifications.unread_count(db, author) == 2

    items = await notifications.list_notifications(db, author)
    assert {item.type for item in items} == {'comment', 'like'}
    assert all(item.actor_nickname == '댓글러' for item in items)

    await notifications.mark_read(db, author, items[0].id)
    assert await notifications.unread_count(db, author) == 1
    await notifications.mark_all_read(db, author)
    assert await notifications.unread_count(db, author) == 0


@pytest.mark.asyncio
async def test_repeated_like_toggle_does_not_spam_notifications(db):
    community = CommunityService()
    notifications = NotificationService()
    author = User(kakao_id='notif-author-2', nickname='작성자')
    liker = User(kakao_id='notif-liker', nickname='좋아요러')
    db.add_all([author, liker])
    await db.commit()
    post = await community.create_post(db, author, region='서울 종로구', board='free', title='글', caption='내용')

    await community.like(db, post.id, liker, True)
    await community.like(db, post.id, liker, False)
    await community.like(db, post.id, liker, True)
    assert await notifications.unread_count(db, author) == 1


@pytest.mark.asyncio
async def test_notify_on_like_off_suppresses_like_notifications(db):
    community = CommunityService()
    notifications = NotificationService()
    author = User(kakao_id='notif-author-3', nickname='작성자', notify_on_like=False)
    liker = User(kakao_id='notif-liker-2', nickname='좋아요러')
    db.add_all([author, liker])
    await db.commit()
    post = await community.create_post(db, author, region='서울 종로구', board='free', title='글', caption='내용')

    await community.add_comment(db, post.id, liker, '댓글')
    await community.like(db, post.id, liker, True)

    items = await notifications.list_notifications(db, author)
    assert [item.type for item in items] == ['comment']
