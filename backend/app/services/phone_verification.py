import datetime
import hashlib
import re
import secrets

from fastapi import HTTPException
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.security import create_phone_verification_token
from ..db.models import PhoneVerification
from .sms import SmsService

_CODE_TTL_MINUTES = 5
_RESEND_COOLDOWN_SECONDS = 60
_MAX_VERIFY_ATTEMPTS = 5
_KOREAN_MOBILE_RE = re.compile(r"^01[016789]\d{7,8}$")


def normalize_phone_number(raw: str) -> str:
    """"010-1234-5678"/"010 1234 5678" 등을 숫자만 남긴 "01012345678"로 통일한다.
    국내 휴대폰 번호 형식이 아니면 422."""
    digits = re.sub(r"\D", "", raw)
    if not _KOREAN_MOBILE_RE.match(digits):
        raise HTTPException(422, "올바른 휴대폰 번호를 입력해주세요")
    return digits


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


class PhoneVerificationService:
    """자체 회원가입의 휴대폰 본인확인 — 인증번호 발송/검증. 검증에 성공하면
    회원가입 요청에 실어 보낼 짧은 유효기간 토큰을 발급한다(그 사이 다른 번호로
    가입을 시도하는 걸 막기 위해 phone_number를 토큰 안에 서명해 넣는다)."""

    def __init__(self, sms_service: SmsService | None = None) -> None:
        self._sms = sms_service or SmsService()

    @property
    def is_live(self) -> bool:
        return self._sms.is_live

    async def send_code(self, db: AsyncSession, raw_phone_number: str) -> None:
        phone_number = normalize_phone_number(raw_phone_number)
        now = datetime.datetime.now(datetime.timezone.utc)

        latest = await db.scalar(
            select(PhoneVerification)
            .where(PhoneVerification.phone_number == phone_number)
            .order_by(desc(PhoneVerification.created_at))
            .limit(1)
        )
        if latest is not None and (now - latest.created_at) < datetime.timedelta(seconds=_RESEND_COOLDOWN_SECONDS):
            raise HTTPException(429, "잠시 후 다시 시도해주세요")

        code = f"{secrets.randbelow(1_000_000):06d}"
        db.add(
            PhoneVerification(
                phone_number=phone_number,
                code_hash=_hash_code(code),
                expires_at=now + datetime.timedelta(minutes=_CODE_TTL_MINUTES),
            )
        )
        await db.commit()
        await self._sms.send_sms(phone_number, f"[옛길] 인증번호 [{code}]를 {_CODE_TTL_MINUTES}분 이내에 입력해주세요.")

    async def verify_code(self, db: AsyncSession, raw_phone_number: str, code: str) -> str:
        phone_number = normalize_phone_number(raw_phone_number)
        now = datetime.datetime.now(datetime.timezone.utc)

        record = await db.scalar(
            select(PhoneVerification)
            .where(PhoneVerification.phone_number == phone_number, PhoneVerification.verified_at.is_(None))
            .order_by(desc(PhoneVerification.created_at))
            .limit(1)
        )
        if record is None or record.expires_at < now:
            raise HTTPException(400, "인증번호가 만료되었어요. 다시 요청해주세요")
        if record.attempt_count >= _MAX_VERIFY_ATTEMPTS:
            raise HTTPException(429, "시도 횟수를 초과했어요. 인증번호를 다시 요청해주세요")
        if record.code_hash != _hash_code(code):
            record.attempt_count += 1
            await db.commit()
            raise HTTPException(400, "인증번호가 올바르지 않아요")

        record.verified_at = now
        await db.commit()
        return create_phone_verification_token(phone_number)
