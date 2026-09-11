from ..core.config import settings


class SentimentClient:
    """KcELECTRA → ONNX 감성분석 서빙 클라이언트.

    ml/serving에 모델이 없는 개발 초기에는 고정 목 점수를 반환한다.
    """

    def __init__(self) -> None:
        self._model_path = settings.sentiment_model_path

    async def score(self, text: str) -> float:
        # TODO: onnxruntime.InferenceSession(self._model_path)로 실제 추론 연결.
        if not text:
            return 0.5
        return round(min(0.5 + len(text) % 40 / 100, 0.95), 2)
