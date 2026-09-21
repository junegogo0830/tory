from fastapi import APIRouter

from ...models.chatbot import ChatbotMessageRequest, ChatbotMessageResponse
from ...services.chatbot import ChatbotService

router = APIRouter(prefix="/api/chatbot", tags=["chatbot"])
_service = ChatbotService()

_FALLBACK_REPLY = "지금은 답을 드리기 어렵네요. 잠시 후 다시 물어봐 주시게."


@router.post("/message", response_model=ChatbotMessageResponse)
async def send_message(body: ChatbotMessageRequest) -> ChatbotMessageResponse:
    reply = await _service.reply(
        mode=body.mode,
        history=[turn.model_dump() for turn in body.history],
        message=body.message,
    )
    return ChatbotMessageResponse(reply=reply or _FALLBACK_REPLY)
