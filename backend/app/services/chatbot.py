import logging

import httpx

from ..core.config import settings

logger = logging.getLogger(__name__)

_MODEL = "gemini-2.5-flash"
# GEMINI_API_KEY는 Vertex AI Express Mode 키(조직 정책상 aiplatform.googleapis.com
# 외 다른 API로는 못 넓힌다)라, AI Studio용 generativelanguage.googleapis.com이
# 아니라 이 전역 Vertex AI 엔드포인트 + x-goog-api-key 헤더로 호출해야 한다.
_API_URL = f"https://aiplatform.googleapis.com/v1/publishers/google/models/{_MODEL}:generateContent"
_TIMEOUT_SECONDS = 20
_MAX_HISTORY_TURNS = 20  # 대화가 길어져도 매 호출마다 최근 것만 보내 컨텍스트를 제한한다.

_PERSONA = """당신은 대한민국 지역 여행/추억 앱 "옛길"의 챗봇 캐릭터 "훈장님"입니다.
서당 훈장님처럼 지혜롭고 다정한 어른의 말투를 살짝 담되, 과하게 예스러운 표현으로
이해를 방해하지 않습니다. 항상 정중한 존댓말을 씁니다."""

# 제미나이가 앱에 대해 정확히 답하도록, 실제 기능을 요약해 시스템 프롬프트에
# 그대로 실어 전달한다(모델이 매 호출마다 이 지식을 근거로 답하는, 고정
# 지식베이스 기반의 RAG 방식) — 없는 기능을 지어내지 않게 하는 것이 핵심이다.
_APP_KNOWLEDGE = """
[옛길 앱 기능 요약 — 답변의 유일한 근거로 삼으세요. 여기 없는 기능은 안다고
지어내지 말고 정직하게 모른다고 답하세요.]

- 추천 코스: 지역이나 현재 위치를 기반으로 AI가 관광 코스를 자동으로 만들어줍니다.
  방문 순서, 예상 소요 시간, 코스 분위기(산책/역사/미식 등), 감성 점수, 날씨 정보를
  함께 보여줍니다.
- 내 주변: GPS 기반 지도에서 현재 위치 주변의 장소를 검색하고 둘러볼 수 있습니다.
- 둘러보기: 관광지를 사진과 함께 탐색할 수 있는 화면입니다.
- 맛집 추천: 카카오맵 데이터를 기반으로 식당을 카테고리별로 추천해줍니다.
- 식사 추가: 추천 코스 상세 화면에서 "식사를 추가하시겠어요?"를 누르면 아침/점심/
  저녁 시간대, 음식 종류(여러 개 선택 가능), 가격대, 연령대를 고르고, 코스 동선에서
  크게 벗어나지 않는 실제 식당을 AI가 추천해 코스에 더할 수 있습니다. 후보를
  하나씩 고르지 않고 "한 번에 채우기"로 시간대별 1순위 추천을 한 번에 반영할
  수도 있습니다. 식당을 추가한 뒤에는 꼭 코스를 "저장"해야 나중에 다시 봤을 때도
  남아있습니다.
- 나만의 코스 등록: 사용자가 직접 코스를 만들 수 있습니다. 장소를 순서대로 담고,
  각 장소에 메모와 사진을 직접 등록할 수 있으며, 완성한 코스는 다른 사람과
  공유할 수 있습니다.
- 코스 저장(북마크): 추천 코스와 내가 등록한 코스 모두 저장할 수 있고, 프로필의
  "저장한 코스"에서 다시 볼 수 있습니다.
- 완주 체크: 코스 상세에서 "이 코스 완주했어요" 버튼으로 완주를 기록할 수 있습니다.
- 커뮤니티(지역 게시판): 지역구마다 자유/추억/주민/관광정보 4개 게시판이 있습니다.
  게시판마다 카테고리(예: 취미/여가, 맛집/음식, 친구 등)를 골라 글을 쓸 수 있고,
  프로필 사진과 닉네임, 글 사진(여러 장), 조회수·좋아요·댓글·공유 기능이 있습니다.
  부적절한 글/댓글은 신고할 수 있고, 신고가 일정 수 쌓이면 자동으로 숨김 처리됩니다.
  주민 게시판에서는 중고거래(가격·거래상태 표시) 글도 쓸 수 있습니다.
- 타임캡슐: 추억 게시판에서 글을 쓸 때 "봉인 날짜"를 미래로 정해두면, 그 날짜가
  되기 전까지는 제목·내용·사진이 잠긴 채로만 보이다가 날짜가 되면 자동으로
  공개되는 기능입니다.
- 그 시절 이야기: 내가 등록한 고향/지역과 관련된 옛 뉴스와 이야기를 모아 보여주는
  아카이브 기능입니다.
- 고향 비교: 고향이나 예전에 살던 동네를 등록하면, 그 동네의 예전 모습과 지금
  모습을 비교해볼 수 있습니다.
- 동창·이웃 찾기(추억 매칭): 모교나 예전에 살았던 동네를 프로필에 등록하면, 같은
  학교·동네 출신인 다른 사용자를 찾아 연결(친구) 요청을 보낼 수 있습니다.
- 친구 연결: 다른 사용자에게 연결 요청을 보내고, 수락되면 서로 메시지를 주고받을
  수 있습니다.
- 알림: 내 글에 댓글이나 좋아요가 달리면 알림을 받을 수 있습니다(설정에서 끌 수
  있습니다).
- 프로필: 등록한 코스/저장한 코스/등록한 게시글 수를 보여주고, 나이·성별·이름·
  전화번호·사는 곳을 수정할 수 있습니다. 닉네임 변경·비밀번호 변경·회원 탈퇴도
  프로필에서 합니다.
- 로그인: 아이디/비밀번호로 자체 회원가입하거나, 카카오 계정으로 간편하게
  시작할 수 있습니다.
"""

_FAQ_RULES = """
[지금 대화 모드: 앱 기능 안내]
사용자가 옛길 앱 사용법이나 기능에 대해 궁금해합니다. 위 기능 요약을 근거로
친절하고 구체적으로 답하세요. 답은 채팅창에 맞게 3~6문장 이내로 짧게, 마크다운
기호(별표, # 등) 없이 자연스러운 문장으로 답하세요.
"""

_COURSE_RULES = """
[지금 대화 모드: 코스 짜드리기]
사용자가 여행 코스를 추천받고 싶어합니다. 먼저 어느 지역인지, 누구와 함께인지,
원하는 분위기(산책/역사/미식 등)나 식사 포함 여부를 자연스럽게 대화로 물어보고,
답이 모이면 어울릴 만한 코스를 이야기하듯 제안하세요. 제안 끝에는 실제로 코스를
받으려면 앱의 "추천 코스"(지역 자동 생성)나 "코스 등록"(직접 만들기) 화면에서
방금 나눈 지역/취향 키워드로 찾아보시라고 안내하세요. 답은 채팅창에 맞게 3~6문장
이내로 짧게, 마크다운 기호 없이 자연스러운 문장으로 답하세요.
"""

_FAQ_SYSTEM_PROMPT = _PERSONA + _APP_KNOWLEDGE + _FAQ_RULES
_COURSE_SYSTEM_PROMPT = _PERSONA + _APP_KNOWLEDGE + _COURSE_RULES


class ChatbotService:
    """구글 제미나이 기반 "훈장님" 챗봇.

    GEMINI_API_KEY가 없거나 호출이 실패하면 항상 None을 반환한다(절대 예외를
    올리지 않는다) — 라우트가 안내 문구로 폴백한다.
    """

    async def reply(self, *, mode: str, history: list[dict], message: str) -> str | None:
        if not settings.gemini_api_key:
            return None

        system_prompt = _COURSE_SYSTEM_PROMPT if mode == "course" else _FAQ_SYSTEM_PROMPT
        contents = [
            {"role": turn["role"], "parts": [{"text": turn["text"]}]} for turn in history[-_MAX_HISTORY_TURNS:]
        ]
        contents.append({"role": "user", "parts": [{"text": message}]})

        payload = {
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": contents,
            "generationConfig": {
                "maxOutputTokens": 1024,
                "temperature": 0.7,
                # 기본으로 켜진 확장 사고(thinking)가 maxOutputTokens 예산을
                # 답변과 나눠 쓰면서 답이 중간에 끊기는 원인이 됐다 — 짧은 채팅
                # 응답에는 필요 없어 꺼서 예산 전부를 실제 답변에 쓰게 한다.
                "thinkingConfig": {"thinkingBudget": 0},
            },
        }

        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
                response = await client.post(
                    _API_URL, headers={"x-goog-api-key": settings.gemini_api_key}, json=payload
                )
                response.raise_for_status()
                data = response.json()
        except httpx.HTTPError:
            logger.exception("Gemini chatbot request failed")
            return None

        try:
            parts = data["candidates"][0]["content"]["parts"]
            text = "".join(part.get("text", "") for part in parts).strip()
            return text or None
        except (KeyError, IndexError, TypeError):
            logger.warning("Unexpected Gemini response shape: %s", data)
            return None
