import asyncio
import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile, status

from ..core.config import settings

_ALLOWED_CONTENT_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
_ALLOWED_MIME_BY_EXTENSION = {v: k for k, v in _ALLOWED_CONTENT_TYPES.items()}


def _upload_to_gcs(*, path: str, contents: bytes, content_type: str) -> str:
    from google.cloud import storage  # 로컬 개발에선 gcs_bucket_name이 비어 있어 이 임포트 자체가 필요 없다.

    client = storage.Client()
    bucket = client.bucket(settings.gcs_bucket_name)
    blob = bucket.blob(path)
    blob.upload_from_string(contents, content_type=content_type)
    return f"https://storage.googleapis.com/{settings.gcs_bucket_name}/{path}"


async def save_uploaded_photo(file: UploadFile, *, upload_dir: str, max_bytes: int, public_path_prefix: str) -> str:
    """업로드 사진을 검증(용량·실제 파일 헤더)하고 저장해 접근 가능한 URL을 돌려준다.

    커뮤니티 게시글 사진과 프로필 사진이 같은 규칙(8MB, jpg/png/webp, 매직바이트
    검사)을 쓰므로 공용 유틸로 뺐다.

    Cloud Run 컨테이너의 로컬 디스크는 인스턴스마다 별개이고 재시작되면
    사라지는 휘발성 저장소라, 로컬 디스크에 쓴 사진은 업로드 직후엔 보이다가
    다른 인스턴스가 요청을 받거나 인스턴스가 재활용되는 순간 그냥 사라진다
    (실제로 이래서 커스텀 코스 사진 등록이 "안 되는" 것처럼 보였다). 그래서
    `gcs_bucket_name`이 설정돼 있으면(운영 배포) Google Cloud Storage에
    영구 저장하고, 로컬 개발처럼 비어 있으면 예전처럼 로컬 디스크에 쓴다.
    """
    extension = _ALLOWED_CONTENT_TYPES.get(file.content_type or "")
    if extension is None:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="jpg/png/webp 사진만 올릴 수 있어요")

    contents = await file.read(max_bytes + 1)
    if len(contents) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"사진은 {max_bytes // (1024 * 1024)}MB 이하만 올릴 수 있어요",
        )

    valid = (
        contents.startswith(b'\xff\xd8\xff') if extension == '.jpg'
        else contents.startswith(b'\x89PNG\r\n\x1a\n') if extension == '.png'
        else contents[:4] == b'RIFF' and contents[8:12] == b'WEBP'
    )
    if not valid:
        raise HTTPException(415, '실제 jpg/png/webp 사진을 선택해주세요')

    filename = f"{uuid.uuid4().hex}{extension}"

    if settings.gcs_bucket_name:
        content_type = _ALLOWED_MIME_BY_EXTENSION[extension]
        return await asyncio.to_thread(
            _upload_to_gcs, path=f"{public_path_prefix}/{filename}", contents=contents, content_type=content_type
        )

    directory = Path(upload_dir)
    directory.mkdir(parents=True, exist_ok=True)
    await asyncio.to_thread((directory / filename).write_bytes, contents)
    return f"/uploads/{public_path_prefix}/{filename}"
