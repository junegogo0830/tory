import asyncio
import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile, status

_ALLOWED_CONTENT_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}


async def save_uploaded_photo(file: UploadFile, *, upload_dir: str, max_bytes: int) -> str:
    """업로드 사진을 검증(용량·실제 파일 헤더)하고 디스크에 저장해 파일명을 돌려준다.

    커뮤니티 게시글 사진과 프로필 사진이 같은 규칙(8MB, jpg/png/webp, 매직바이트
    검사)을 쓰므로 공용 유틸로 뺐다.
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

    directory = Path(upload_dir)
    directory.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid.uuid4().hex}{extension}"
    await asyncio.to_thread((directory / filename).write_bytes, contents)
    return filename
