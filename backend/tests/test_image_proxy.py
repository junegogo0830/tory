import asyncio
import httpx
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api.routes import image

@pytest.mark.parametrize('url',['http://127.0.0.1/a','https://visitkorea.or.kr.evil.test/a','https://example.com/a','file:///tmp/a','https://user@tong.visitkorea.or.kr/a'])
def test_proxy_rejects_untrusted(url):
    with TestClient(app) as client:
        assert client.get('/api/image/proxy',params={'url':url}).status_code==400

@pytest.mark.asyncio
async def test_repeated_and_concurrent_images_download_once(monkeypatch):
    import time
    image._cache.clear()
    calls=[]
    async def fetch(url):
        calls.append(url)
        await asyncio.sleep(.02)
        entry=(time.monotonic()+60,b'photo','image/jpeg','etag')
        image._cache[url]=entry
        return entry
    monkeypatch.setattr(image,'_fetch',fetch)
    result=await asyncio.gather(*(image.get_image('https://tong.visitkorea.or.kr/a') for _ in range(10)))
    assert len(calls)==1
    assert all(r[1]==b'photo' for r in result)
    await image.get_image('https://tong.visitkorea.or.kr/a')
    assert len(calls)==1

@pytest.mark.asyncio
async def test_proxy_redirect_is_validated(monkeypatch):
    original=httpx.AsyncClient
    def handler(request):
        return httpx.Response(302,headers={'location':'http://127.0.0.1/private'})
    monkeypatch.setattr(image.httpx,'AsyncClient',lambda **kwargs: original(transport=httpx.MockTransport(handler),**kwargs))
    from fastapi import HTTPException
    with pytest.raises(HTTPException) as error: await image._fetch('https://tong.visitkorea.or.kr/redirect')
    assert error.value.status_code==400


@pytest.mark.asyncio
async def test_tourapi_jpg_mime_alias(monkeypatch):
    original=httpx.AsyncClient
    def handler(request):
        return httpx.Response(200,headers={'content-type':'image/jpg'},content=b'\xff\xd8\xffphoto')
    monkeypatch.setattr(image.httpx,'AsyncClient',lambda **kwargs:original(transport=httpx.MockTransport(handler),**kwargs))
    entry=await image._fetch('https://tong.visitkorea.or.kr/jpeg-alias')
    assert entry[2]=='image/jpeg'
    assert entry[1].startswith(b'\xff\xd8\xff')
