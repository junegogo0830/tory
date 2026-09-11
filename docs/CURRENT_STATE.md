# 옛길 (Yetgil) — 현재 상태 스냅샷

> 작성일: 2026-08-11. `PROJECT_BRIEF.md`가 "이렇게 만들어라"는 킥오프 스펙이라면, 이 문서는
> "지금 실제로 뭐가 어디까지 만들어져 있는지"를 코드 기준으로 정리한 현황판입니다.
> 디자인 수정 포인트를 잡을 때 화면/컴포넌트 단위로 참고하세요.

---

## 1. 한 줄 요약

고향 주소·학교·아파트를 입력하면 **과거↔현재 거리 비교 + 그 시절 지역 뉴스 + 감성분석 기반 추천 코스**를
보여주는 위치 기반 추억 여행 앱. 한국관광공사 「2026 관광데이터 활용 공모전」 출품작.

**핵심 상태 한 줄**: 앱 UI와 백엔드 API가 각각 **독립적으로** 목(mock) 데이터로 동작 중이며,
**둘은 아직 실제로 연결되어 있지 않음.** (4장 참고 — 다음 단계의 핵심 이슈)

---

## 2. 모노레포 구조

```
tory/
├── app/       # Flutter 앱 (iOS/Android/Web/Desktop 스캐폴딩 포함)
├── backend/   # FastAPI 백엔드
├── ml/        # KcELECTRA 감성분석 → ONNX 서빙 (placeholder)
├── infra/     # docker-compose (Postgres + Redis)
└── docs/      # 기획 문서 (PROJECT_BRIEF.md, 이 문서)
```

---

## 3. 앱 (Flutter) — 화면 & 라우팅

### 3.1 라우트 맵 (`app_router.dart`)

| 경로 | 화면 | 비고 |
|---|---|---|
| `/` | `HomeScreen` (추억) | 하단 탭 0 |
| `/explore` | `ExploreScreen` (둘러보기) | 하단 탭 1 |
| `/course` | `CourseListScreen` (코스) | 하단 탭 2 |
| `/profile` | `ProfileScreen` | 하단 탭 3 |
| `/compare/:locationId` | `CompareScreen` | 풀스크린 push (탭 밖) |
| `/archive/:locationId` | `ArchiveScreen` | 풀스크린 push |
| `/course/:courseId` | `CourseDetailScreen` | 풀스크린 push |

하단 탭바(iOS 스타일, `AppShell`): **추억 / 둘러보기 / 코스 / 프로필** 4탭, `StatefulShellRoute`로 탭별 네비게이션 스택 유지.

### 3.2 기능 모듈 (`lib/features/`)

- **home** — 홈(추억) 화면 + 둘러보기(explore) 화면. 입력 진입 카드, 기능 바로가기, 최근 둘러본 골목.
- **compare** — 과거↔현재 비교 슬라이더 (`CompareSlider` 위젯, `ClipRect`+`GestureDetector` 네이티브 구현, WebView 아님).
- **archive** — 그 시절 지역 뉴스 타임라인.
- **course** — 코스 리스트 + 코스 상세.
- **profile** — 프로필 화면 (스캐폴딩만 존재, 기능 미정).

각 기능은 `data/`(Riverpod provider)와 `presentation/`(화면·위젯)으로 분리된 feature-first 구조.

### 3.3 공용 위젯 (`lib/shared/widgets/`)

`AppCard`, `EmptyState`, `SectionHeader`, `FeatureShortcutTile`, `YetgilMark`(로고 마크) — 디자인 수정 시 여기부터 손대면 전 화면에 반영됨.

### 3.4 디자인 시스템 (실제 코드 값, `lib/core/theme/`)

**컬러 (`app_colors.dart`)** — 2026-08-11 갱신, 액센트를 골드→브라운으로 교체:

| 토큰 | 값 | 용도 |
|---|---|---|
| paper | `#F2EFEA` | 화면 배경 |
| surface | `#FFFFFF` | 카드 |
| fieldBg | `#F4F1EC` | 입력 필드 |
| ink | `#1F1A16` | 본문 텍스트 |
| inkSecondary | `#8C857B` | 보조 텍스트 |
| inkTertiary | `#B3ADA2` | placeholder |
| accent | `#6A452C` | 시그니처 액센트 (구 `gold` `#C2901E`) |
| accentTint | `#EFE4D9` | 아이콘 배경 틴트 (구 `goldTint`) |
| accentDeep | `#4A2F1D` | accent 틴트 위 텍스트 (구 `goldDeep`) |
| hairline | `#ECE5DA` | 구분선 |
| charcoal | `#2B2826` | 로고 차콜 |

타이포그래피는 iOS 타입스케일 + Pretendard (largeTitle 27/700 ~ caption 11/400) +
숫자/단위 강조 페어(`statNumber` 48/700, `statUnit` 24/400, 2:1 비율 — 신규),
엘리베이션은 연한 2-레이어 그림자(`cardShadow`/`tileShadow`), 코너 라운딩은
카드 18 / 버튼 14 / 입력필드 13 / 필 18 / 타일 14.
→ **디자인 수정은 이 5개 파일(`app_colors`/`app_typography`/`app_shadows`/`app_radius`/`app_theme`)만
고치면 전 화면에 전파되는 구조**이니, 톤 변경 시 여기부터 시작하면 됩니다.
디자인 판단 기준(왜 이렇게 만드는지)은 [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) 참고.

### 3.5 패키지 (`pubspec.yaml`)

`flutter_riverpod` 3.3.2(상태관리) · `go_router` 17.3.0(라우팅) · `dio` 5.10.0(HTTP) ·
`cached_network_image` · `webview_flutter`(로드뷰 임베드용, 아직 미사용) · 폰트 Pretendard 4 굵기.

### 3.6 로고

`assets/logo/`에 자리만 잡은 placeholder. 실제 벡터 트레이싱(SVG) 미완료 — **디자인 작업 1순위 후보.**

---

## 4. 백엔드 (FastAPI)

### 4.1 엔드포인트

| 메서드/경로 | 설명 | 데이터 상태 |
|---|---|---|
| `GET /health` | 헬스체크 | 정상 (`{"status":"ok"}`) |
| `GET /api/location?query=` | 자유입력 → 장소 매칭 | **Mock 3곳** 하드코딩, TourAPI 키 있어도 응답 매핑은 TODO (아래 참고) |
| `GET /api/location/{id}` | ID로 장소 조회 | Mock |
| `GET /api/archive/{location_id}` | 장소별 뉴스 타임라인 | 서비스 존재, 빈 결과 시 빈 배열 반환(폴백 OK) |
| `GET /api/course` | 전체 코스 목록 | Mock 3개 장소 중 2곳만 데이터 있음 |
| `GET /api/course/detail/{id}` | 코스 상세 | Mock, 404 처리 있음 |
| `GET /api/course/by-location/{id}` | 장소별 추천 코스 | Mock |

### 4.2 서비스 계층 실제 상태

- **`tourapi.py`**: `TOUR_API_KEY` 없으면 mock 3곳(순천 전포동/군산 중앙로/영월장) 중 이름·지역 텍스트 매칭으로 반환.
  **키가 있어도** `_fetch_location()`은 실제 API를 호출은 하지만 응답을 그대로 버리고 **mock을 리턴**함
  (`# TODO: 실제 TourAPI 응답 스키마에 맞춰 LocationResponse로 매핑` — [tourapi.py:92](backend/app/services/tourapi.py#L92)).
  Redis 캐싱(TTL 1시간)은 구현되어 있고 Redis 장애 시 조용히 스킵하는 방어 로직도 있음.
- **`recommendation.py`**: 코스 추천 100% 하드코딩 딕셔너리. `SentimentClient` 주입은 받지만 실제로 호출해서
  점수를 쓰진 않음 — `sentiment_score`도 목 값.
- **`sentiment_client.py`**: ONNX 모델 없음. `score()`는 `len(text) % 40`로 만든 **가짜 점수** 반환.
- **`archive.py`** (서비스): 네이버 뉴스 연동 여부 미확인 — 별도 확인 필요.

### 4.3 DB/캐시

PostgreSQL + Redis 연결 모듈(`db/postgres.py`, `db/redis.py`)은 존재하나, 위 서비스들이 실제로
Postgres에 쓰기/읽기를 하는지는 목 데이터 위주라 **사실상 미사용에 가까움** (Redis는 캐시로만 부분 사용).

---

## 5. ML 파이프라인

`ml/training/train_sentiment.py`, `ml/serving/export_onnx.py`, `ml/serving/inference.py` 모두
**CLI 골격 + `NotImplementedError`만 있는 placeholder.** 학습 데이터셋(`ml/data/`)도 비어있음(gitignore).
→ 감성분석은 당분간 백엔드의 가짜 점수로 대체된 상태이며, 실제 학습은 별도 트랙.

---

## 6. 인프라

`infra/docker-compose.yml`: `postgres:16-alpine` + `redis:7-alpine`, 헬스체크 포함. 문법 검증은 됐지만
이 환경엔 WSL2가 없어 **실행 자체는 미검증** 상태 (README에 명시됨).

---

## 7. 환경 변수 / 외부 API 키 현황

`.env.example` 기준, 전부 **비어있음(미발급)**:

| 변수 | 용도 | 발급처 |
|---|---|---|
| `TOUR_API_KEY` | 관광지 데이터 (필수) | data.go.kr — TourAPI 4.0 |
| `NAVER_NEWS_CLIENT_ID` / `_SECRET` | 지역 뉴스 검색 | developers.naver.com |
| `KAKAO_MAP_JS_KEY` | 지도/로드뷰 | developers.kakao.com |
| `DATABASE_URL`, `REDIS_URL` | 로컬 인프라 | 자체 docker-compose |

---

## 8. 구현 상태 총괄표

| 영역 | 상태 |
|---|---|
| Flutter 디자인 시스템(색/타입/그림자/라운딩) | ✅ 코드화 완료, 브리프와 일치 |
| Flutter 4개 탭 + 3개 상세 화면 라우팅 | ✅ 동작 |
| 비교 슬라이더 (네이티브 제스처) | ✅ 구현됨 |
| **Flutter ↔ FastAPI 실제 연결** | ❌ **미연결** — 레포지토리가 로컬 mock 반환, `ApiClient` 미사용 |
| FastAPI 3개 도메인 엔드포인트 | ✅ 응답은 하지만 전부 mock |
| TourAPI 실연동 | ⚠️ 키 없음 + 응답 매핑 코드 TODO |
| 네이버 뉴스 실연동 | ❓ 미확인 (archive 서비스 코드 추가 확인 필요) |
| 카카오맵/로드뷰 | ❌ 미착수 (`webview_flutter`만 설치됨) |
| 감성분석(KcELECTRA→ONNX) | ❌ placeholder, 가짜 점수 |
| Postgres 실사용 | ❌ 연결 모듈만 존재, 실제 read/write 없음 |
| 로고 벡터화 | ❌ placeholder |
| Docker 인프라 실행 검증 | ⚠️ 문법만 검증, 미실행 |

---

## 9. 디자인 리뷰 체크리스트 (화면별)

수정 사항 가져올 때 아래 단위로 정리하면 반영이 빠릅니다.

- [ ] 홈(추억) — 입력 카드, 바로가기 타일, 최근 골목 카드
- [ ] 둘러보기(explore)
- [ ] 비교 슬라이더 — 이음새(seam) 브라운 라인 모티프, 연도 선택 UI, 캡션
- [ ] 아카이브(뉴스 타임라인) — 빈 상태(empty-state) 디자인
- [ ] 코스 리스트 / 코스 상세
- [ ] 프로필 (현재 스캐폴딩만 존재 — 컨셉부터 필요할 수 있음)
- [ ] 하단 탭바 아이콘 (현재 Material 기본 아이콘 — 커스텀 아이콘 필요 여부)
- [ ] 로고/엠블럼 벡터화

---

## 10. 알려진 제약 (브리프에서 유지 중)

1. 시크릿은 `.env`로만, 코드/히스토리에 커밋 금지.
2. 카카오 로드뷰는 "과거 이미지" 제공 안 함 — 과거는 큐레이션 보유 이미지, 현재는 로드뷰/TourAPI 이미지.
3. 리뷰 크롤링 금지(ToS 위반) — 감성모델은 공개 데이터셋(NSMC 등)만 사용.
4. 콜드스팟(인구감소지역)은 관광지 데이터가 희박 → 모든 화면에 빈 상태 폴백 필수 (현재 archive/course는 반영됨).
