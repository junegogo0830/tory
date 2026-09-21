import io
import os
import uuid
import pytest
import pytest_asyncio
from fastapi import HTTPException, UploadFile
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from sqlalchemy import text
from app.core.config import settings
from app.db.base import Base
from app.db.models import User
from app.models.community import PostUpdateRequest
from app.services.community import CommunityService
from app.services.notifications import NotificationService

pytestmark=pytest.mark.skipif(os.environ.get('RUN_DB_TESTS') != '1',reason='Requires isolated PostgreSQL schema')

@pytest_asyncio.fixture
async def db():
    # A unique schema isolates integration tests from every application table.
    schema='test_'+uuid.uuid4().hex
    admin=create_async_engine(settings.database_url)
    async with admin.begin() as conn: await conn.execute(text('CREATE SCHEMA '+schema))
    engine=create_async_engine(settings.database_url,connect_args={'server_settings':{'search_path':schema}})
    try:
        async with engine.begin() as conn: await conn.run_sync(Base.metadata.create_all)
        async with async_sessionmaker(engine,expire_on_commit=False)() as session: yield session
    finally:
        await engine.dispose()
        async with admin.begin() as conn: await conn.execute(text('DROP SCHEMA '+schema+' CASCADE'))
        await admin.dispose()

@pytest.mark.asyncio
async def test_post_comment_like_ownership_and_cascade(db):
    service=CommunityService()
    author=User(kakao_id='test-author',nickname='작성자')
    other=User(kakao_id='test-other',nickname='방문자')
    db.add_all([author,other]); await db.commit()
    post=await service.create_post(db,author,region='서울 종로구',board='free',title='이야기',caption='본문')
    await service.add_comment(db,post.id,other,'좋은 이야기예요')
    await service.like(db,post.id,other,True)
    await service.like(db,post.id,other,True)
    detail=await service.detail(db,post.id,other)
    assert detail.like_count==1 and detail.comment_count==1 and detail.liked
    assert not detail.is_mine
    with pytest.raises(HTTPException) as exc: await service.update(db,post.id,other,PostUpdateRequest(title='변경',caption='내용'))
    assert exc.value.status_code==403
    edited=await service.update(db,post.id,author,PostUpdateRequest(title='수정',caption='내용'))
    assert edited.title=='수정'
    assert len(await service.list_posts(db,region='서울 종로구',board='free',query='수정'))==1
    await service.like(db,post.id,other,False)
    assert (await service.detail(db,post.id)).like_count==0
    comment=(await service.comments(db,post.id,other))[0]
    with pytest.raises(HTTPException): await service.remove_comment(db,post.id,comment.id,author)
    await service.remove(db,post.id,author)
    with pytest.raises(HTTPException): await service.detail(db,post.id)
    assert (await db.execute(text('SELECT count(*) FROM community_comments'))).scalar()==0


@pytest.mark.asyncio
async def test_photo_url_not_double_prefixed_when_already_a_full_url(db, monkeypatch):
    """save_uploaded_photo는 GCS 배포 환경(gcs_bucket_name 설정됨)에서 이미
    완성된 절대 URL(https://storage.googleapis.com/...)을 돌려준다 — 그런데
    한때 create_post/_to_response/_photo_urls가 그 값 앞에 또
    "/uploads/community/"를 덧붙여, 실제 배포에서 업로드한 사진이 깨진
    경로가 되는 바람에 기본 이미지로만 보이는 버그가 있었다. 글쓰기 직후
    응답과 상세 조회(detail) 양쪽 다 원래 URL 그대로 나오는지 확인한다."""
    fake_url = "https://storage.googleapis.com/fake-bucket/community/abc123.jpg"

    async def _fake_save_photo(self, file):  # noqa: ARG001
        return fake_url

    monkeypatch.setattr(CommunityService, "_save_photo", _fake_save_photo)

    service = CommunityService()
    author = User(kakao_id="photo-author", nickname="작성자")
    db.add(author)
    await db.commit()

    upload = UploadFile(filename="photo.jpg", file=io.BytesIO(b"fake-bytes"))
    created = await service.create_post(
        db, author, region="서울 종로구", board="free", title="사진 테스트", caption="본문", files=[upload]
    )
    assert created.photo_url == fake_url
    assert created.photo_urls == [fake_url]

    detail = await service.detail(db, created.id)
    assert detail.photo_url == fake_url
    assert detail.photo_urls == [fake_url]


@pytest.mark.asyncio
async def test_report_auto_hides_after_threshold(db):
    service = CommunityService()
    author = User(kakao_id='report-author', nickname='작성자')
    reporters = [User(kakao_id=f'reporter-{i}', nickname=f'신고자{i}') for i in range(3)]
    db.add_all([author, *reporters])
    await db.commit()
    post = await service.create_post(db, author, region='서울 종로구', board='free', title='도배글', caption='내용')

    # 신고 2번까지는 그대로 보인다.
    for reporter in reporters[:2]:
        await service.report(db, reporter, target_type='post', target_id=post.id, reason='스팸이에요')
    assert len(await service.list_posts(db, region='서울 종로구', board='free')) == 1

    # 같은 사람이 두 번 신고해도 중복 집계되지 않는다.
    await service.report(db, reporters[0], target_type='post', target_id=post.id, reason='또 신고')
    assert len(await service.list_posts(db, region='서울 종로구', board='free')) == 1

    # 세 번째(서로 다른) 신고자부터 자동 숨김 처리된다.
    await service.report(db, reporters[2], target_type='post', target_id=post.id, reason='스팸이에요')
    assert len(await service.list_posts(db, region='서울 종로구', board='free')) == 0
    with pytest.raises(HTTPException):
        await service.detail(db, post.id, author)


@pytest.mark.asyncio
async def test_block_hides_posts_and_comments_from_blocker(db):
    service = CommunityService()
    blocker = User(kakao_id='blocker', nickname='나')
    blocked = User(kakao_id='blocked-user', nickname='싫은사람')
    db.add_all([blocker, blocked])
    await db.commit()
    post = await service.create_post(db, blocked, region='서울 종로구', board='free', title='글', caption='내용')
    await service.add_comment(db, post.id, blocked, '댓글')

    await service.block(db, blocker, blocked.id)
    assert await service.list_posts(db, region='서울 종로구', board='free', viewer_id=blocker.id) == []
    with pytest.raises(HTTPException):
        await service.detail(db, post.id, blocker)

    # 차단 안 한 다른 사람에게는 그대로 보인다.
    assert len(await service.list_posts(db, region='서울 종로구', board='free')) == 1

    await service.unblock(db, blocker, blocked.id)
    assert len(await service.list_posts(db, region='서울 종로구', board='free', viewer_id=blocker.id)) == 1


@pytest.mark.asyncio
async def test_neighbors_lists_same_home_region_users(db):
    service = CommunityService()
    me = User(kakao_id='neighbor-me', nickname='나', home_region='경기 수원시 영통구')
    same_region = User(kakao_id='neighbor-same', nickname='이웃', home_region='경기 수원시 영통구')
    other_region = User(kakao_id='neighbor-other', nickname='다른동네', home_region='서울 종로구')
    db.add_all([me, same_region, other_region])
    await db.commit()
    await service.create_post(db, same_region, region='경기 수원시 영통구', board='resident', title='동네소식', caption='내용')

    neighbors = await service.neighbors(db, me, region='경기 수원시 영통구')
    assert [n.nickname for n in neighbors] == ['이웃']
    assert neighbors[0].post_count == 1

    # 차단하면 이웃 목록에서도 빠진다.
    await service.block(db, me, same_region.id)
    assert await service.neighbors(db, me, region='경기 수원시 영통구') == []


class _FakeUploadFile:
    def __init__(self, content: bytes, content_type: str = 'image/jpeg', filename: str = 'p.jpg') -> None:
        self.content_type = content_type
        self.filename = filename
        self._content = content

    async def read(self, _n: int) -> bytes:
        return self._content


@pytest.mark.asyncio
async def test_create_post_supports_multiple_photos(db):
    service = CommunityService()
    author = User(kakao_id='multi-photo', nickname='작성자')
    db.add(author)
    await db.commit()

    files = [_FakeUploadFile(b'\xff\xd8\xff' + bytes([i]) * 20) for i in range(3)]
    post = await service.create_post(db, author, region='서울 종로구', board='memory', title='여러장', files=files)
    assert len(post.photo_urls) == 3
    assert post.photo_url == post.photo_urls[0]

    detail = await service.detail(db, post.id, author)
    assert len(detail.photo_urls) == 3


@pytest.mark.asyncio
async def test_memory_board_requires_at_least_one_photo(db):
    service = CommunityService()
    author = User(kakao_id='memory-no-photo', nickname='작성자')
    db.add(author)
    await db.commit()
    with pytest.raises(HTTPException) as exc:
        await service.create_post(db, author, region='서울 종로구', board='memory', title='사진없음')
    assert exc.value.status_code == 422


@pytest.mark.asyncio
async def test_comment_reply_flattens_to_one_level_and_notifies(db):
    service = CommunityService()
    notifications = NotificationService()
    author = User(kakao_id='reply-author', nickname='글쓴이')
    top = User(kakao_id='reply-top', nickname='첫댓글러')
    replier = User(kakao_id='reply-replier', nickname='답글러')
    db.add_all([author, top, replier])
    await db.commit()
    post = await service.create_post(db, author, region='서울 종로구', board='free', title='글', caption='내용')

    top_comment = await service.add_comment(db, post.id, top, '첫 댓글')
    reply = await service.add_comment(db, post.id, replier, '답글이요', parent_id=top_comment.id)
    assert reply.parent_id == top_comment.id

    # 답글에 또 답글을 달아도 같은 최상위 댓글에 묶인다(1단계 스레드만 유지).
    reply2 = await service.add_comment(db, post.id, author, '또 답글', parent_id=reply.id)
    assert reply2.parent_id == top_comment.id

    # 글쓴이(author)는 top/replier가 단 댓글 2개에 대해 알림을 받고(본인이 단 reply2는 제외),
    # 첫댓글러(top)는 replier·author 각각의 답글로 2번 알림을 받는다.
    assert await notifications.unread_count(db, author) == 2
    assert await notifications.unread_count(db, top) == 2
    assert await notifications.unread_count(db, replier) == 0


@pytest.mark.asyncio
async def test_list_posts_by_user_scopes_to_region(db):
    service = CommunityService()
    author = User(kakao_id='byuser-author', nickname='작성자')
    db.add(author)
    await db.commit()
    await service.create_post(db, author, region='서울 종로구', board='free', title='종로글', caption='내용')
    await service.create_post(db, author, region='경기 수원시', board='free', title='수원글', caption='내용')

    posts = await service.list_posts_by_user(db, author_id=author.id, region='서울 종로구')
    assert [p.title for p in posts] == ['종로글']

    # region 없이 부르면(프로필 "등록한 게시글") 지역 무관 전체 글이 나온다.
    all_posts = await service.list_posts_by_user(db, author_id=author.id)
    assert {p.title for p in all_posts} == {'종로글', '수원글'}
