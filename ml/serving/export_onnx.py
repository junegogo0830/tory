"""파인튜닝된 KcELECTRA 체크포인트를 ONNX로 변환하는 스크립트 (placeholder).

실행 계획:
  transformers.onnx 또는 optimum.exporters.onnx를 사용해
  ml/training/checkpoints/의 체크포인트를 ml/serving/model.onnx로 export한다.
"""

import argparse


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="KcELECTRA 체크포인트 → ONNX 변환")
    parser.add_argument("--checkpoint-dir", default="ml/training/checkpoints")
    parser.add_argument("--output-path", default="ml/serving/model.onnx")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    raise NotImplementedError(
        "학습된 체크포인트 확보 후 구현 예정. "
        f"checkpoint_dir={args.checkpoint_dir}, output_path={args.output_path}"
    )


if __name__ == "__main__":
    main()
