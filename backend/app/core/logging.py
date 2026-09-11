import logging
import sys

from .config import settings


def configure_logging() -> None:
    level = logging.DEBUG if settings.debug else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
        stream=sys.stdout,
    )

    # httpx/httpcore의 DEBUG 레벨은 요청마다 TCP 연결·TLS 핸드셰이크·응답 헤더
    # 전체를 통째로 찍어서 터미널이 순식간에 뒤덮인다. 우리 앱 코드는 DEBUG로
    # 보고 싶어도, 이 두 라이브러리는 항상 WARNING 이상만 보이게 눌러둔다.
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
