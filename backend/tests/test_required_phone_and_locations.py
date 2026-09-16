from unittest.mock import AsyncMock, Mock

import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app
from app.models.auth import SignupRequest
from app.models.location import LocationResponse
from app.services.auth import AuthService
from app.services.hero_locations import HERO_LOCATIONS
from app.services.phone_verification import PhoneVerificationService
from app.services.sms import SmsSendError, SmsService
from app.services.tourapi import TourApiService


@pytest.mark.asyncio
async def test_missing_sms_settings_never_log_or_accept_code(monkeypatch, caplog):
    monkeypatch.setattr(settings, 'ncp_sens_sender_number', '')
    with pytest.raises(SmsSendError):
        await SmsService().send_sms('01012345678', '123456')
    assert '01012345678' not in caplog.text
    assert '123456' not in caplog.text


@pytest.mark.asyncio
@pytest.mark.parametrize('error', [SmsSendError('rejected'), httpx.ConnectTimeout('timeout')])
async def test_failed_sms_rolls_back_verification(error):
    db = Mock(scalar=AsyncMock(return_value=None), commit=AsyncMock(), rollback=AsyncMock())
    service = PhoneVerificationService(Mock(send_sms=AsyncMock(side_effect=error)))
    with pytest.raises(HTTPException) as exc:
        await service.send_code(db, '01012345678')
    assert exc.value.status_code == 503
    db.rollback.assert_awaited_once()
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_unverified_signup_rejected_even_without_sms_settings(monkeypatch):
    monkeypatch.setattr(settings, 'ncp_sens_sender_number', '')
    db = Mock(scalar=AsyncMock(return_value=None), commit=AsyncMock())
    with pytest.raises(ValueError, match='휴대폰 인증'):
        await AuthService().signup(db, SignupRequest(
            username='tester01', password='password123', agree_terms=True, agree_privacy=True,
        ))
    db.commit.assert_not_awaited()
    assert TestClient(app).get('/api/auth/phone/required').json() == {'required': True}


@pytest.mark.parametrize('slug', HERO_LOCATIONS)
def test_hero_detail_available_without_search_or_cache(slug, monkeypatch):
    async def fail(*args, **kwargs):
        raise AssertionError('Fixed banner detail must not call external search')
    monkeypatch.setattr(TourApiService, 'resolve_location', fail)
    response = TestClient(app).get('/api/location/hero-' + slug)
    assert response.status_code == 200
    place = response.json()
    assert place['latitude'] and place['longitude']
    assert place['past_year'] == place['current_year']
    assert place['name'] == HERO_LOCATIONS[slug][0]


def test_tour_search_uses_only_tourism_source(monkeypatch):
    async def attractions(self, query, num_rows, *, content_type_id='12'):
        assert query == '공원'
        return [LocationResponse(id='tour-1', name='공원', region='강릉', description='',
                                 past_year=2026, current_year=2026, source='tourapi')]
    async def fail(*args, **kwargs):
        raise AssertionError('TourAPI tab must not use general Kakao search')
    monkeypatch.setattr(TourApiService, 'search_attractions', attractions)
    monkeypatch.setattr(TourApiService, 'search_locations', fail)
    response = TestClient(app).get('/api/location/tour-search', params={'query': '공원'})
    assert response.status_code == 200
    assert response.json()[0]['source'] == 'tourapi'


def test_tour_search_passes_content_type_id_filter(monkeypatch):
    """홈 화면 검색 필터 — content_type_id를 넘기면 그 카테고리로 검색을 좁힌다."""
    seen = {}
    async def attractions(self, query, num_rows, *, content_type_id='12'):
        seen['content_type_id'] = content_type_id
        return []
    monkeypatch.setattr(TourApiService, 'search_attractions', attractions)
    response = TestClient(app).get(
        '/api/location/tour-search', params={'query': '맛집', 'content_type_id': '39'}
    )
    assert response.status_code == 200
    assert seen['content_type_id'] == '39'


def test_tour_search_rejects_unknown_content_type_id(monkeypatch):
    """알 수 없는 content_type_id는 기본값(관광지)으로 조용히 대체한다."""
    seen = {}
    async def attractions(self, query, num_rows, *, content_type_id='12'):
        seen['content_type_id'] = content_type_id
        return []
    monkeypatch.setattr(TourApiService, 'search_attractions', attractions)
    response = TestClient(app).get(
        '/api/location/tour-search', params={'query': '아무거나', 'content_type_id': 'nope'}
    )
    assert response.status_code == 200
    assert seen['content_type_id'] == '12'


def test_leave_region_requires_login():
    assert TestClient(app).delete('/api/community/my-regions', params={'region': '서울'}).status_code == 401
