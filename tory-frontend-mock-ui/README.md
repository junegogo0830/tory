# 옛길 (Yetgil)

고향 주소·학교·살던 아파트를 입력하면 그곳의 **과거 거리 모습 + 그 시절 지역 뉴스 + 달라진 현재 관광코스**를 함께 보여주는 위치 기반 추억 여행 앱.

> 한국관광공사 「2026 관광데이터 활용 공모전 — 웹·앱 개발 부문」 출품작.

## 모노레포 구조

```
yetgil/
├── app/       # Flutter 앱 (iOS/Android)
├── backend/   # FastAPI 백엔드
├── ml/        # KcELECTRA 감성분석 → ONNX 서빙
├── infra/     # docker-compose (Postgres + Redis)
└── docs/      # 기획 문서, API 계약
```

기획 배경, 디자인 시스템 토큰, 화면 범위 등 전체 맥락은 [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md)를 참고하세요.

## 사전 준비물

| 도구 | 용도 | 확인 명령 |
|---|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable) | `app/` 실행 | `flutter --version` |
| Python 3.10+ | `backend/` 실행 | `python --version` |
| Docker Desktop (WSL2 backend) | `infra/` (Postgres + Redis) | `docker compose version` |

Windows에서 Docker Desktop을 처음 쓴다면 WSL2 활성화가 필요합니다 (관리자 PowerShell에서 `wsl --install` 실행 후 재부팅).

## 빠른 시작

키가 없어도 세 파트 모두 목(mock) 데이터로 동작합니다. 순서는 상관없지만 아래 순으로 띄우는 것을 권장합니다.

### 1. infra (Postgres + Redis)

```bash
cd infra
docker compose up -d
```

> `backend`는 Postgres/Redis 없이도 목 데이터로 뜨므로, infra 준비 전에 backend부터 확인해도 됩니다.

### 2. backend (FastAPI)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate       # Windows
# source .venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
uvicorn app.main:app --reload
```

- Health check: http://localhost:8000/health → `{"status": "ok"}`
- API 문서(Swagger): http://localhost:8000/docs
- 장소 스텁 예시: http://localhost:8000/api/location?query=전라남도%20순천시

테스트 실행: `pytest` (backend 디렉터리에서)

### 3. app (Flutter)

```bash
cd app
flutter pub get
flutter run -d chrome   # 또는 flutter devices로 확인한 다른 디바이스
```

홈 화면(추억)이 옛길 디자인 시스템(베이지 배경 + 흰 카드 + 골드 포인트)으로 뜨면 정상입니다.

위젯 테스트: `flutter test` (app 디렉터리에서)

## 환경 변수

루트의 `.env.example`을 복사해 `.env`로 만들고 값을 채우세요. `.env`는 절대 커밋하지 않습니다 (`.gitignore`에 포함됨). TourAPI/네이버뉴스/카카오맵 키가 비어 있어도 목 데이터로 정상 동작합니다.

## 기술 스택

| 레이어 | 선택 |
|---|---|
| 앱 | Flutter (Riverpod, go_router, dio, Pretendard) |
| 백엔드 | FastAPI (pydantic-settings, httpx, redis, SQLAlchemy+asyncpg) |
| DB / 캐시 | PostgreSQL + Redis |
| ML | KcELECTRA → ONNX (`ml/` — 현재 placeholder, 백엔드는 목 감성 점수 사용) |

## 현재 상태 / 알려진 제약

- **Docker/WSL2**: 이 저장소를 스캐폴딩한 환경에는 WSL2가 활성화되어 있지 않아 `docker compose up -d`는
  아직 실행 검증되지 않았습니다 (`docker compose config`로 파일 문법은 검증 완료). WSL2 활성화 후 실행해보세요.
- **ml/**: KcELECTRA 파인튜닝·ONNX 변환은 학습 데이터셋 확보 전이라 CLI 골격만 있는 placeholder 상태입니다.
- **로고**: `app/assets/logo/`에 자리만 잡아둔 placeholder이며, 실제 벡터 트레이싱은 별도 작업입니다.
- **TourAPI/네이버뉴스/카카오맵 연동**: 키 발급 전이라 백엔드가 목 데이터로 응답하도록 되어 있습니다.
