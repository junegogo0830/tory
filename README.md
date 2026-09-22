# 옛길 (Yetgil)

고향이나 예전에 살던 동네·학교 정보를 입력하면 그 시절의 모습(옛 뉴스 아카이브,
로드뷰 비교)을 돌아보고, AI가 추천하는 맞춤 여행 코스와 맛집으로 달라진 고향을
다시 여행하며, 동네 커뮤니티와 동창·이웃 찾기로 사람과 다시 연결되는 위치 기반
추억 여행 + 지역 커뮤니티 앱.

> 한국관광공사 「2026 관광데이터 활용 공모전 — 웹·앱 개발 부문」 출품작.

전체 기능/기술 스택/화면 구성/디자인 시스템/개발 중 트러블슈팅까지 정리한 종합
자료는 [`PORTFOLIO_CONTEXT.md`](PORTFOLIO_CONTEXT.md)를 참고하세요. 최초 기획
배경·요구사항은 [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md)에 있습니다
(초기 킥오프 스펙이라 현재 구현과는 차이가 있을 수 있습니다).

## 핵심 기능 요약

- **AI 여행 코스 추천**: 지역/GPS 기반, 한국관광공사 TourAPI 후보 + Claude가 방문
  순서·소요시간·감성 점수·날씨를 포함한 코스 생성
- **AI 맛집 추천 & 코스 반영**: 시간대/음식종류/가격대/연령대 조건으로 식당 추천,
  결정론적 알고리즘으로 동선을 해치지 않는 위치에 자동 삽입
- **나만의 코스 등록/저장/공유**: 장소·메모·사진을 직접 등록해 코스를 만들고 공유,
  완주 체크
- **지역 기반 커뮤니티**: 자유/추억/주민/관광정보 4개 게시판, 카테고리 필터, 타임캡슐
  (예약 공개), 중고거래, 신고·자동 숨김
- **그 시절 이야기 / 고향 비교**: 네이버 뉴스 아카이브 기반 옛 이야기, 로드뷰로
  그때와 지금 비교
- **동창·이웃 찾기**: 모교·거주 이력 기반 추억 매칭, 친구 연결·메시지
- **AI 챗봇 "훈장님"**: Gemini 기반, 앱 기능 안내와 코스 상담을 슬라이드 시트
  UI로 제공
- **소셜 로그인**: 카카오 로그인(노출 중) + 네이버 로그인(구현 완료, 현재 플래그로
  비노출) + 자체 아이디/비밀번호 회원가입(휴대폰 인증 필수)

## 모노레포 구조

```
tory/
├── app/               # Flutter 앱 (Android/Web)
├── backend/           # FastAPI 백엔드
├── ml/                # 감성분석 → ONNX 서빙 (아직 placeholder, 8절 참고)
├── infra/             # docker-compose (로컬 개발용 Postgres + Redis)
├── docs/              # 기획/설계 문서 (일부는 초기 스냅샷이라 현재와 다를 수 있음)
├── store_assets/      # 스토어 등록용 스크린샷/그래픽 자료
└── PORTFOLIO_CONTEXT.md  # 포트폴리오/노션 작성용 종합 자료
```

## 사전 준비물

| 도구 | 용도 | 확인 명령 |
|---|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable) | `app/` 실행 | `flutter --version` |
| Python 3.10+ | `backend/` 실행 | `python --version` |
| Docker Desktop (WSL2 backend) | `infra/` (Postgres + Redis) — 로컬 개발용 | `docker compose version` |

Windows에서 Docker Desktop을 처음 쓴다면 WSL2 활성화가 필요합니다 (관리자 PowerShell에서 `wsl --install` 실행 후 재부팅).

## 빠른 시작 (로컬 개발)

외부 API 키가 없어도 대부분의 화면은 뜹니다(해당 기능만 빈 응답/폴백으로
동작). 순서는 상관없지만 아래 순으로 띄우는 것을 권장합니다.

### 1. infra (Postgres + Redis)

```bash
cd infra
docker compose up -d
```

### 2. backend (FastAPI)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate       # Windows
# source .venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
alembic upgrade head          # 전체 테이블 생성 (Postgres 필요)
uvicorn app.main:app --reload
```

- Health check: http://localhost:8000/health → `{"status": "ok"}`
- API 문서(Swagger): http://localhost:8000/docs

`/api/auth/*`, `/api/profile*`, `/api/community/*` 등 로그인이 필요한 대부분의
엔드포인트는 실제 Postgres 연결이 필요합니다. 외부 API 키(TourAPI/카카오/Claude/
Gemini 등)가 비어 있으면 해당 기능만 빈 결과나 안내 문구로 조용히 폴백합니다
(예외를 던지지 않음).

테스트 실행: `pytest` (backend 디렉터리에서). `RUN_DB_TESTS=1 pytest`로 실행하면
실제 Postgres가 필요한 통합 테스트까지 함께 돕니다.

### 3. app (Flutter)

```bash
cd app
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=KAKAO_NATIVE_APP_KEY=<카카오 네이티브 앱 키> \
  --dart-define=KAKAO_JAVASCRIPT_APP_KEY=<카카오 JavaScript 키>
```

홈 화면이 옛길 디자인 시스템(웜 베이지 배경 + 브라운 포인트 컬러)으로 뜨면
정상입니다.

위젯 테스트: `flutter test` (app 디렉터리에서)

Android 릴리즈 APK 빌드 예시:

```bash
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=<배포된 백엔드 URL> \
  --dart-define=KAKAO_NATIVE_APP_KEY=<...> \
  --dart-define=KAKAO_JAVASCRIPT_APP_KEY=<...>
```

카카오 로그인을 네이티브 앱에서 쓰려면 `android/local.properties`에
`kakao.nativeAppKey=...`도 함께 채워야 합니다(`android/app/build.gradle.kts`가
이 값을 manifest placeholder로 주입). 자세한 내용은
[`docs/KAKAO_LOGIN_SETUP.md`](docs/KAKAO_LOGIN_SETUP.md) 참고.

## 환경 변수

루트의 `.env.example`을 복사해 `.env`로 만들고 값을 채우세요. `.env`는 절대
커밋하지 않습니다(`.gitignore`에 포함됨). 아래 키들은 비어 있어도 서버가 죽지
않고, 해당 키를 쓰는 기능만 조용히 폴백합니다(예: 사진 없이 응답, 챗봇 안내
문구 반환 등).

| 키 | 용도 |
|---|---|
| `DATABASE_URL` / `POSTGRES_*` | Postgres 연결 |
| `REDIS_URL` / `REDIS_HOST` / `REDIS_PORT` | Redis 연결(캐싱) |
| `TOUR_API_KEY`, `TOUR_PHOTO_API_KEY` | 한국관광공사 TourAPI(관광정보/관광사진) |
| `KAKAO_MAP_JS_KEY`, `KAKAO_REST_API_KEY` | 카카오 로컬/맵/로그인(웹) |
| `GOOGLE_MAPS_API_KEY` | Google Places 사진 보강 |
| `NAVER_NEWS_CLIENT_ID`, `NAVER_NEWS_CLIENT_SECRET` | 네이버 뉴스 검색(그 시절 이야기) |
| `NAVER_LOGIN_CLIENT_ID`, `NAVER_LOGIN_CLIENT_SECRET` | 네이버 로그인(백엔드는 구현 완료, 현재 프론트에서 플래그로 비노출) |
| `ANTHROPIC_API_KEY` | Claude API — 코스 생성, 맛집 추천 랭킹 |
| `GEMINI_API_KEY` | Gemini API(Vertex AI) — 챗봇 "훈장님" |
| `NCP_ACCESS_KEY`, `NCP_SECRET_KEY`, `NCP_SENS_SERVICE_ID`, `NCP_SENS_SENDER_NUMBER` | 휴대폰 본인인증 SMS(NCP SENS) — 넷 중 하나라도 비면 발송 실패 처리 |
| `OPENWEATHER_API_KEY` | 코스 날씨 정보 |
| `GCS_BUCKET_NAME` | 업로드 사진 저장 — 비어 있으면 로컬 디스크, 채워져 있으면 Google Cloud Storage |
| `JWT_SECRET_KEY` | 반드시 `openssl rand -hex 32`로 생성한 값으로 교체(배포 환경은 기본값이면 기동 거부) |

실제 배포 절차는 [`infra/DEPLOY.md`](infra/DEPLOY.md)를 참고하세요.

## 기술 스택

| 레이어 | 선택 |
|---|---|
| 앱 | Flutter, flutter_riverpod, go_router, dio, cached_network_image, kakao_flutter_sdk |
| 백엔드 | FastAPI, SQLAlchemy(async)+asyncpg, Alembic, Redis, httpx |
| DB / 캐시 | PostgreSQL 16 (Cloud SQL), Redis |
| 저장소 | Google Cloud Storage (사용자 업로드 사진) |
| 배포 | Google Cloud Run(백엔드), Cloud Build(이미지 빌드), Artifact Registry |
| AI | Anthropic Claude API(코스/맛집 추천), Google Gemini API(챗봇) |
| 외부 데이터 | 한국관광공사 TourAPI, 카카오(로컬/맵/로그인), 네이버(뉴스 검색/로그인/SENS), Google Maps Platform, OpenWeatherMap |
| ML | 감성분석 → ONNX 서빙 (`ml/` — 아직 placeholder, 8절 참고) |

## 현재 상태 / 알려진 제약

- **백엔드는 Google Cloud Run에 실제 배포되어 동작 중**입니다(`yetgil-backend`,
  `asia-northeast3`). 위 "빠른 시작"은 로컬 개발 기준이며, 실제 서비스는 Cloud SQL
  + Cloud Storage + 외부 API 전부와 연동돼 있습니다.
- **Android APK 빌드 완료, 원스토어(OneStore) 앱 등록 및 심사 통과**했습니다. 웹
  버전은 로컬 검증까지만 진행했고, 별도 도메인으로의 정식 웹 배포는 아직입니다.
- **감성분석(`ml/`, `SentimentClient`)은 아직 실제 모델이 아닙니다.** 텍스트
  길이 기반으로 점수를 계산하는 더미(mock) 구현이며, ONNX 추론 연결은 TODO로
  남아 있습니다 — 포트폴리오/보고서 작성 시 "KoBERT" 등 특정 모델명을 단정적으로
  쓰지 않도록 주의하세요.
- **네이버 로그인**: 백엔드 엔드포인트와 프론트 화면 모두 구현을 마쳤지만, 네이버
  측 앱 심사(캡처 제출 등) 절차 때문에 `AppConstants.showNaverLogin` 플래그로 현재는
  화면에서 숨겨져 있습니다. 카카오 로그인만 노출 중입니다.
- **로컬 Docker/WSL2 개발 환경**: 이 문서의 `docker compose up -d` 절차는 WSL2가
  필요합니다. 실제 배포 환경(Cloud SQL/Memorystore)과는 별개입니다.
