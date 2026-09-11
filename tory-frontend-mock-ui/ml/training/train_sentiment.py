"""KcELECTRA 감성분석 파인튜닝 스크립트 (placeholder).

파이프라인 초안:
  1. NSMC 등 공개 한국어 감성분석 데이터셋을 ml/data/에 배치한다.
  2. beomi/KcELECTRA-base를 HuggingFace Transformers로 로드해 이진/다중 분류 헤드를 파인튜닝한다.
  3. 학습 산출물은 ml/training/checkpoints/에 저장한다 (gitignore 대상).
  4. 이후 serving/export_onnx.py로 ONNX 변환한다.

실제 학습 코드는 데이터셋 확보 후 구현 예정. 지금은 CLI 골격만 정의한다.
"""

import argparse


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="KcELECTRA 감성분석 파인튜닝")
    parser.add_argument("--data-dir", default="ml/data", help="학습 데이터셋 경로")
    parser.add_argument("--output-dir", default="ml/training/checkpoints", help="체크포인트 저장 경로")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--learning-rate", type=float, default=2e-5)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    raise NotImplementedError(
        "학습 데이터셋 확보 후 구현 예정. "
        f"설정값: data_dir={args.data_dir}, output_dir={args.output_dir}, "
        f"epochs={args.epochs}, batch_size={args.batch_size}, lr={args.learning_rate}"
    )


if __name__ == "__main__":
    main()
