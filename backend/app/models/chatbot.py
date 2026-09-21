from pydantic import BaseModel, Field


class ChatbotTurn(BaseModel):
    role: str = Field(pattern="^(user|model)$")
    text: str = Field(min_length=1, max_length=4000)


class ChatbotMessageRequest(BaseModel):
    mode: str = Field(pattern="^(faq|course)$")
    history: list[ChatbotTurn] = Field(default_factory=list, max_length=40)
    message: str = Field(min_length=1, max_length=2000)


class ChatbotMessageResponse(BaseModel):
    reply: str
