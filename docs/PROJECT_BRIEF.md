# 옛길 (Yetgil) — Claude Code 킥오프 브리프

> 이 문서를 VSCode에서 Claude Code에 **첫 프롬프트로 통째로** 붙여넣으세요.
> 저장 위치 추천: `docs/PROJECT_BRIEF.md`

---

## 0. Claude Code에게 (작업 지침)

- **이 브리프를 끝까지 읽고 시작할 것.** 우리 사전 대화 컨텍스트는 이 문서에 다 담겨 있음.
- 목표: 아래 모노레포를 **스캐폴딩**하고, 각 파트를 **실제로 실행 가능한 상태**까지 만든 뒤 실행을 검증할 것.
- **단계별로 진행하고, 각 단계마다 실행이 되는지 확인**할 것. 한 번에 전부 쏟아내지 말 것.
- **시크릿(API 키)을 코드에 하드코딩 금지.** 반드시 `.env` 주입 방식.
- 파괴적 작업(파일 대량 삭제, force push 등) 전에는 **먼저 물어볼 것.**
- 폴더 구조와 디자인 토큰은 **아래 정의를 그대로** 따를 것 (임의 변경 금지).
- 아직 API 키가 없어도 **목(mock) 데이터로 앱/서버가 뜨도록** 만들 것.

---

## 1. 프로젝트 개요

**옛길**: 고향 주소·학교·살던 아파트를 입력하면 그곳의 **과거 거리 모습 + 그 시절 지역 뉴스 + 달라진 현재 관광코스**를 함께 보여주는 위치 기반 추억 여행 앱.

- 맥락: 한국관광공사 「2026 관광데이터 활용 공모전 — 웹·앱 개발 부문」 출품작.
- 타깃: 인구감소지역(콜드스팟) 우선, 수도권 이주 2030 세대의 고향 재방문 유도.
- 품질 기준: **프로덕션급 완성도**. 기본형·조악한 결과물 불가.

**핵심 사용자 플로우**
1. 고향 주소/학교/아파트 입력
2. 과거↔현재 거리 **비교 슬라이더** (시그니처 기능)
3. 그 시절 지역 뉴스 **타임라인**
4. 감성분석 기반 **현재 관광코스 추천**

---

## 2. 기술 스택 (확정 — 변경 금지)

| 레이어 | 선택 |
|---|---|
| 앱 | **Flutter** (iOS/Android) |
| 백엔드 | **FastAPI** (Python) |
| DB / 캐시 | **PostgreSQL + Redis** |
| ML | **KcELECTRA** 감성분석 → **ONNX** 서빙 |
| 데이터 | TourAPI 4.0(필수) · 네이버 뉴스 라이브러리 · 국가기록원 · 큐레이션 로드뷰 아카이브 |

**권장 Flutter 패키지** (Claude Code가 최종 확정): `flutter_riverpod`(상태관리), `go_router`(라우팅), `dio`(HTTP), `webview_flutter`(카카오 로드뷰 임베드), `cached_network_image`, `pretendard`(폰트).

**권장 백엔드 패키지**: `fastapi`, `uvicorn[standard]`, `httpx`(async 외부 API), `redis`, `pydantic-settings`, `sqlalchemy`+`asyncpg`.

---

## 3. 모노레포 폴더 구조 (이대로 생성)

```
yetgil/
├── app/                       # Flutter 앱
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/              # 디자인 시스템·라우터·상수
│   │   │   ├── theme/         #   app_colors / app_typography / app_shadows / app_theme
│   │   │   ├── router/
│   │   │   └── constants/
│   │   ├── data/              # api 클라이언트·모델·레포지토리
│   │   │   ├── api/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── features/          # 기능별 모듈 (feature-first)
│   │   │   ├── home/
│   │   │   ├── compare/       #   과거↔현재 비교
│   │   │   ├── archive/       #   그시절 뉴스
│   │   │   └── course/        #   추천 코스
│   │   └── shared/            # 공용 위젯 (카드·버튼·엘리베이션)
│   ├── assets/
│   │   ├── logo/              # 엠블럼(풀/단순화), 앱아이콘
│   │   ├── fonts/
│   │   └── images/            # 큐레이션 과거/현재 이미지
│   └── pubspec.yaml
├── backend/                   # FastAPI
│   ├── app/
│   │   ├── main.py
│   │   ├── core/              # config(settings), 로깅
│   │   ├── api/routes/        # health, location, archive, course
│   │   ├── services/          # tourapi, archive, recommendation, sentiment_client
│   │   ├── models/            # pydantic 스키마
│   │   └── db/                # postgres, redis 연결
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
├── ml/                        # KcELECTRA 감성분석
│   ├── training/               # 파인튜닝 스크립트 (초기엔 placeholder)
│   ├── serving/                # ONNX export + 추론
│   ├── data/                   # 데이터셋 (gitignore)
│   └── README.md
├── docs/                      # 이 브리프·API 계약·결정 기록
├── infra/
│   └── docker-compose.yml     # postgres + redis
├── .github/                   # (선택) CI 워크플로우
├── .gitignore
├── .env.example
└── README.md
```

---

## 4. 디자인 시스템 토큰 (그대로 코드화 — `app/lib/core/theme/`)

방향성: **iOS 네이티브 감성 + 소프트 엘리베이션.** 따뜻한 베이지 바닥 위에 흰 카드가 연한 그림자로 떠 있음. 색은 99% 무채색, **골드는 포인트로만.** 절제가 핵심.

**컬러 (`app_colors.dart` — AppColors 클래스로)**
```
paper        #F2EFEA   // 화면 배경 (따뜻한 베이지)
surface      #FFFFFF   // 카드
fieldBg      #F4F1EC   // 입력 필드·서브 영역
ink          #1F1A16   // 본문 텍스트
inkSecondary #8C857B   // 보조 텍스트
inkTertiary  #B3ADA2   // placeholder
gold         #C2901E   // 시그니처 액센트 (로고 골드값 = 이 토큰)
goldTint     #F6EEDD   // 아이콘 배경 틴트
goldDeep     #8A5512   // 골드 틴트 위 텍스트
hairline     #ECE5DA   // 구분선·보더
charcoal     #2B2826   // 로고 차콜
```

**엘리베이션 (`app_shadows.dart`)** — 연하게. 진하면 촌스러워짐.
```
cardShadow:  0 1px 2px rgba(31,26,22,0.04), 0 8px 20px rgba(31,26,22,0.06)
tileShadow:  0 1px 2px rgba(31,26,22,0.04), 0 6px 16px rgba(31,26,22,0.06)
```

**타이포그래피 (`app_typography.dart`)** — iOS 타입스케일.
```
largeTitle  27  w700   headline  17  w600   subhead   14  w400
title       20  w600   body      16  w400   footnote  13  w400
                                             caption   11  w400
```
> 폰트: **Pretendard** 사용 (오픈소스, iOS/한국앱 느낌에 최적, Flutter `pretendard` 패키지). SF Pro / Apple SD Gothic Neo는 앱 배포 라이선스상 사용 불가하니 Pretendard로 대체.

**코너 라운딩 (연속 곡률 느낌)**: 카드 18, 버튼 14, 입력필드 13, 필/칩 18, 타일 14.

**컴포넌트 원칙**
- 섹션은 헤어라인 대신 **떠 있는 흰 카드**로 구분.
- 주요 CTA = ink(`#1F1A16`) 채움 버튼 / 액센트·선택상태 = gold.
- 사진 영역은 **풀블리드 + 라운딩 + 저채도**. 색은 사진이 담당.
- **이음새(seam) 모티프**: 과거↔현재를 가르는 골드 세로선을 비교 썸네일·전환에 반복.

---

## 5. 로고 시스템

- **풀 엠블럼**(원형 인장 + 지도핀 + 옛길 글자, 차콜/골드): 스플래시·앱스토어·마케팅 등 큰 자리. → 원본은 래스터이므로 **SVG 벡터로 트레이싱**해서 `assets/logo/`에 배치 (별도 진행).
- **단순화 마크**(원 + 이음새 + 골드핀): 헤더·탭바·파비콘·앱아이콘. 16px까지 또렷.
- 헤더는 **엠블럼 단독**으로도 성립 (워드마크 선택).
- 초기 스캐폴딩에서는 `assets/logo/`에 placeholder를 두고 위치만 잡아둘 것.

---

## 6. 화면/기능 범위 (MVP)

- **홈(추억)**: 입력 진입 카드 + 기능 바로가기(비교/뉴스/코스/지도) + 최근 둘러본 골목 + 추천 배너. 전부 떠 있는 흰 카드.
- **비교(compare)**: 과거↔현재 이미지 **드래그 슬라이더**(네이티브: `ClipRect` + `GestureDetector`, WebView 아님) + 연도 선택 + 캡션.
- **아카이브(archive)**: 그 시절 지역 뉴스 **타임라인** (빈 결과 폴백 필수).
- **코스(course)**: 감성점수 결합 추천 코스 리스트 → 코스 상세.
- 하단 iOS 탭바: 추억 / 둘러보기 / 코스 / 프로필.

---

## 7. ⚠️ 반드시 지킬 제약 (실패 방지)

1. **시크릿 안전 — 최우선.** 첫 커밋 전에 `.gitignore`(`.env`, `*.key`, 빌드 산출물 포함) + `.env.example`(빈 껍데기) 먼저. 실제 키는 절대 커밋 금지.
2. **카카오 로드뷰 "과거 이미지"는 공식 API로 제공 안 됨.** 과거는 **큐레이션한 보유 이미지**, 현재는 로드뷰 SDK/TourAPI 이미지로 구성. 비교 슬라이더는 이미지 두 장 기반 **네이티브** 구현. (라이브 360° 로드뷰만 선택적으로 WebView 패널.)
3. **리뷰 크롤링 금지** (구글맵·네이버 ToS 위반). 감성모델 학습은 **공개 데이터셋**(NSMC 등), 라이브 점수는 Places API 허용 범위 + 큐레이션 코퍼스.
4. **TourAPI 빈 데이터 대비.** 콜드스팟은 관광지 데이터가 희박할 수 있음 → 모든 화면에 **빈 상태(empty-state) 폴백 UI** 필수.

---

## 8. 작업 순서 (이 순서대로, 각 단계 실행 검증)

1. **레포 초기화**: `git init`, `.gitignore`, `.env.example`, 루트 `README.md`. → 확인 후 진행.
2. **Flutter 앱 스캐폴딩**
   - `flutter create` 로 `app/` 생성, 위 폴더 구조로 재배치.
   - `core/theme/`에 위 디자인 토큰 코드화(AppColors/AppTypography/AppShadows/AppTheme), `go_router` 라우팅, `pretendard` 폰트 세팅.
   - **홈(추억) 화면 스켈레톤**을 디자인 시스템 적용해 구현 (목 데이터).
   - ✅ 검증: `flutter run` → 홈 화면이 떠야 함.
3. **FastAPI 백엔드 스캐폴딩**
   - `backend/app/` 구조 생성, `core/config.py`(pydantic-settings로 `.env` 로드), `GET /health`.
   - `services/tourapi.py` 스텁 + Redis 캐싱 골격, `GET /api/location` 스텁 엔드포인트(키 없으면 목 데이터 반환).
   - ✅ 검증: `uvicorn app.main:app --reload` → `/health`, `/api/location` 동작.
4. **ml/ 구조**: `training/`·`serving/` placeholder 스크립트 + `README.md`(파이프라인 설명). 무거운 학습 코드는 아직 X.
5. **infra**: `docker-compose.yml`로 postgres + redis. ✅ `docker compose up -d` 검증.
6. **README** 최종화: 프로젝트 소개 + **각 파트 실행법**(app/backend/infra) 명확히.
7. **전체 스모크 테스트**: 세 파트가 각각 뜨는지 마지막에 한 번 더 확인.

---

## 9. 완료 기준 (Definition of Done)

- [ ] `flutter run` → 디자인 시스템(색·타이포·엘리베이션)이 적용된 **홈 화면**이 뜬다.
- [ ] `uvicorn` → `/health` 200, `/api/location` 스텁이 (목 데이터로) 응답한다.
- [ ] `docker compose up` → postgres·redis 컨테이너가 뜬다.
- [ ] `.env`는 gitignore 되어 있고, 키가 코드/히스토리에 없다.
- [ ] `README.md`만 보고 팀원이 로컬에서 세 파트를 실행할 수 있다.

---

*작업 중 판단이 필요한 지점(패키지 선택, 세부 구조 등)은 이 브리프의 원칙을 우선하되, 애매하면 진행 전에 질문할 것.*
