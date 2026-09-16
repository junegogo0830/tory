import base64
import hashlib
import hmac
import logging
import time

import httpx

from ..core.config import settings

logger = logging.getLogger(__name__)


class SmsSendError(Exception):
    pass


class SmsService:
    """네이버클라우드 SENS로 문자를 발송한다.

    NCP_ACCESS_KEY/NCP_SECRET_KEY/NCP_SENS_SERVICE_ID/NCP_SENS_SENDER_NUMBER 중
    하나라도 비어 있으면(키 발급 전 로컬 개발 등) 실제로 보내지 않고 로그로만
    남긴다 — 회원가입 전체 흐름(인증번호 발송→입력→검증)을 실제 SMS 계정 없이도
    막힘 없이 개발/테스트할 수 있게 하려는 의도적인 폴백이다.
    """

    _BASE_URL = "https://sens.apigw.ntruss.com"
    _MESSAGES_PATH_TEMPLATE = "/sms/v2/services/{service_id}/messages"

    def _configured(self) -> bool:
        return bool(
            settings.ncp_access_key
            and settings.ncp_secret_key
            and settings.ncp_sens_service_id
            and settings.ncp_sens_sender_number
        )

    @property
    def is_live(self) -> bool:
        """실제로 문자를 보낼 수 있는 상태인지 — 회원가입에서 휴대폰 인증을
        필수로 요구할지 말지가 이 값 하나로 자동으로 결정된다(발신번호가
        승인돼 이 값이 True가 되는 순간, 코드 변경 없이 필수 인증이 켜진다)."""
        return self._configured()

    def _make_signature(self, method: str, url: str, timestamp: str) -> str:
        message = f"{method} {url}\n{timestamp}\n{settings.ncp_access_key}".encode()
        digest = hmac.new(settings.ncp_secret_key.encode(), message, hashlib.sha256).digest()
        return base64.b64encode(digest).decode()

    async def send_sms(self, to: str, content: str) -> None:
        if not self._configured():
            logger.warning("NCP_SENS not configured — logging SMS instead of sending: to=%s content=%s", to, content)
            return

        url = self._MESSAGES_PATH_TEMPLATE.format(service_id=settings.ncp_sens_service_id)
        timestamp = str(int(time.time() * 1000))
        signature = self._make_signature("POST", url, timestamp)

        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                f"{self._BASE_URL}{url}",
                headers={
                    "Content-Type": "application/json; charset=utf-8",
                    "x-ncp-apigw-timestamp": timestamp,
                    "x-ncp-iam-access-key": settings.ncp_access_key,
                    "x-ncp-apigw-signature-v2": signature,
                },
                json={
                    "type": "SMS",
                    "from": settings.ncp_sens_sender_number,
                    "content": content,
                    "messages": [{"to": to}],
                },
            )

        if response.status_code not in (200, 202):
            raise SmsSendError(f"NCP SENS send failed: {response.status_code} {response.text}")
