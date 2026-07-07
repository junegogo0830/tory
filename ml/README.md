# ml — 감성분석 파이프라인

옛길의 "감성분석 기반 현재 관광코스 추천" 기능을 위한 KcELECTRA → ONNX 파이프라인.

## 파이프라인 개요

1. **데이터 수집** (`ml/data/`, gitignore 대상)
   - 공개 데이터셋만 사용한다 (예: NSMC). 리뷰 크롤링은 ToS 위반이므로 금지.
2. **파인튜닝** (`ml/training/train_sentiment.py`)
   - `beomi/KcELECTRA-base`를 HuggingFace Transformers로 로드해 감성 분류 헤드를 학습한다.
3. **ONNX 변환** (`ml/serving/export_onnx.py`)
   - 학습된 체크포인트를 `ml/serving/model.onnx`로 export한다.
4. **서빙** (`ml/serving/inference.py`)
   - `onnxruntime.InferenceSession`으로 모델을 로드해 추론한다.
   - `backend/app/services/sentiment_client.py`의 `SentimentClient`가 이 결과를 소비하도록 연결한다 (현재는 목 점수 반환).

## 현재 상태

- 학습 데이터셋이 아직 없어 `train_sentiment.py` / `export_onnx.py` / `inference.py`는 CLI 골격과
  인터페이스만 정의된 placeholder 상태다 (`NotImplementedError`).
- 백엔드는 `SentimentClient.score()`가 고정 목 점수를 반환하도록 되어 있어, 모델 없이도
  `/api/course` 등 관련 엔드포인트가 정상 동작한다.

## 로컬에서 학습 환경을 준비할 때 (추후)

```bash
cd ml
python -m venv .venv
.venv\Scripts\activate
pip install transformers torch onnx onnxruntime datasets
```
