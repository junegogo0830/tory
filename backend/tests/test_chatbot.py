import httpx
import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app
from app.services.chatbot import ChatbotService

client = TestClient(app)

# conftest.py의 autouse fixture가 ChatbotService.reply 자체를 None 폴백으로
# 막아둔다 — 그 로직을 직접 검증하는 테스트는 패치되기 전 원본을 모듈 임포트
# 시점에 미리 붙잡아둬야 한다(meal_planner 테스트의 같은 패턴).
_REAL_REPLY = ChatbotService.reply


def test_message_falls_back_when_gemini_unavailable() -> None:
    # conftest.py의 autouse fixture가 ChatbotService.reply를 None으로 막아둔다.
    response = client.post("/api/chatbot/message", json={"mode": "faq", "history": [], "message": "코스 등록이 뭐야?"})
    assert response.status_code == 200
    assert response.json()["reply"]  # 실패해도 빈 문자열이 아니라 안내 문구가 온다.


def test_message_rejects_invalid_mode() -> None:
    response = client.post("/api/chatbot/message", json={"mode": "weird", "history": [], "message": "안녕"})
    assert response.status_code == 422


def test_message_returns_service_reply(monkeypatch: pytest.MonkeyPatch) -> None:
    async def _fake_reply(self: ChatbotService, *, mode: str, history: list, message: str) -> str:  # noqa: ARG001
        return "옛길에 오신 걸 환영하네."

    monkeypatch.setattr(ChatbotService, "reply", _fake_reply)

    response = client.post("/api/chatbot/message", json={"mode": "course", "history": [], "message": "부산 코스 짜줘"})
    assert response.json()["reply"] == "옛길에 오신 걸 환영하네."


@pytest.mark.asyncio
async def test_service_returns_none_without_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "gemini_api_key", "")
    service = ChatbotService()
    assert await _REAL_REPLY(service, mode="faq", history=[], message="안녕") is None


@pytest.mark.asyncio
async def test_service_parses_gemini_response(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "gemini_api_key", "fake-key")

    class _FakeResponse:
        def raise_for_status(self) -> None:
            pass

        def json(self) -> dict:
            return {"candidates": [{"content": {"parts": [{"text": "안녕하신가, 나그네."}]}}]}

    class _FakeClient:
        async def __aenter__(self) -> "_FakeClient":
            return self

        async def __aexit__(self, *args: object) -> None:
            return None

        async def post(self, *args: object, **kwargs: object) -> _FakeResponse:
            return _FakeResponse()

    monkeypatch.setattr(httpx, "AsyncClient", lambda *a, **kw: _FakeClient())

    service = ChatbotService()
    reply = await _REAL_REPLY(service, mode="faq", history=[{"role": "user", "text": "안녕"}], message="옛길이 뭐야?")
    assert reply == "안녕하신가, 나그네."


@pytest.mark.asyncio
async def test_service_returns_none_on_http_error(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "gemini_api_key", "fake-key")

    class _FailingClient:
        async def __aenter__(self) -> "_FailingClient":
            return self

        async def __aexit__(self, *args: object) -> None:
            return None

        async def post(self, *args: object, **kwargs: object) -> None:
            raise httpx.ConnectTimeout("boom")

    monkeypatch.setattr(httpx, "AsyncClient", lambda *a, **kw: _FailingClient())

    service = ChatbotService()
    assert await _REAL_REPLY(service, mode="faq", history=[], message="안녕") is None
