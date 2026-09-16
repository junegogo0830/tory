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

    설정이 없으면 발송 실패로 처리한다. 전화번호와 인증번호는 로그에 남기지 않는다.
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
        """발송 설정 존재 여부. 발신번호 승인이나 실제 수신을 보장하지 않는다."""
        return self._configured()

    def _make_signature(self, method: str, url: str, timestamp: str) -> str:
        message = f"{method} {url}\n{timestamp}\n{settings.ncp_access_key}".encode()
        digest = hmac.new(settings.ncp_secret_key.encode(), message, hashlib.sha256).digest()
        return base64.b64encode(digest).decode()

    async def send_sms(self, to: str, content: str) -> None:
        if not self._configured():
            raise SmsSendError("SMS service is not configured")

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
