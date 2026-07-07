"""ONNX 감성분석 모델 추론 래퍼 (placeholder).

model.onnx가 준비되면 onnxruntime.InferenceSession으로 로드해
backend/app/services/sentiment_client.py의 SentimentClient가
이 클래스를 호출하도록 연결한다.
"""

from pathlib import Path


class OnnxSentimentModel:
    def __init__(self, model_path: str = "ml/serving/model.onnx") -> None:
        self._model_path = Path(model_path)
        self._session = None  # onnxruntime.InferenceSession(str(self._model_path))

    def predict(self, text: str) -> float:
        """0.0(부정) ~ 1.0(긍정) 사이 감성 점수를 반환한다."""
        if self._session is None:
            raise NotImplementedError(
                f"{self._model_path} 모델이 아직 준비되지 않았습니다. "
                "export_onnx.py로 모델을 생성한 뒤 세션을 로드하세요."
            )
        raise NotImplementedError
