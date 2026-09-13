# 옛길 구현 및 검증 기록 — 2026-09-12

기존 베이지·브라운 디자인 토큰을 유지했다.

## 구현

- 커뮤니티: 지역/게시판 검색, 20개씩 더보기, 게시글 상세, 댓글(30개씩), 공감, 작성자 글 수정/삭제·댓글 삭제. 공감 PUT/DELETE는 반복해도 중복되지 않는다. 비회원 조회, 회원 쓰기를 서버에서 검사한다.
- 사진: 8MB 제한·파일 헤더 검사, 이미지 선택기의 플랫폼별 권한 처리, PNG/WebP MIME 판별. Docker의 community_uploads 볼륨에 보관한다.
- 추천: 전체/산책/역사/미식/문화/자연/가족, 큐레이션 코스 11개. 먼 구간은 차량 이동으로 표기한다.
- 맞춤 생성: 지역, 현재/지정 날씨, 연령대, 성별, 관심 카테고리, 여행 속도, 1–8시간. TourAPI와 카카오의 실제 좌표가 있는 장소만 사용한다. 날씨는 생성 시 조회한다.
- 날씨에 따라 실내·짧은 이동을 우선하고, 고령층은 보행 속도를 보수적으로 산정한다. 성별로 선호를 추측하지 않는다. 원하는 카테고리를 모두 넣을 수 없으면 결과에 알린다.
- 생성 결과는 7일 캐시하며 URL 상세 조회와 같은 앱 세션에서 즉시 재열기를 지원한다. 사용자 영구 보관함은 이번 구현에 포함하지 않았다.

## 홈 사진 문제

코드에서 확인한 관련 결함은 다음과 같다. 원래 사용자의 PC 증상을 수정 전 브라우저에서 완전히 재현한 것은 아니므로 단일 원인이라고 단정하지 않는다.

1. 코스 생성과 지역 이야기의 동기 AI 호출이 async 서버 이벤트 루프를 차단했다. 제한시간을 둔 별도 스레드에서 처리하도록 수정했다.
2. 이미지 프록시가 원본을 매번 다운로드했다. 64MB/256개 한도의 서버 캐시, 동일 이미지 동시 요청 병합, ETag, CDN 일시 장애 시 기존 사진 재사용을 추가했다.
3. 검색창의 조건부 자식 삽입으로 캐러셀 상태가 교체될 수 있어 고정 key를 부여했다. 가려진 홈에서는 타이머를 진행하지 않고, Enter 검색에서도 입력을 정리한다.
4. 모든 외부 주소를 TourAPI 전용 프록시에 보내던 로직을 호스트에 따라 구분했다. 실제 TourAPI CDN의 image/jpg 응답도 image/jpeg로 정규화한다.

## 검증

- 백엔드 95개 테스트 통과(실제 PostgreSQL의 별도 스키마 통합 테스트 포함).
- Flutter 3개 테스트 통과: 이미지 URL, 맞춤 코스 파싱, 390px 모바일 폭에서 청명역 검색→상세→홈 복귀 시 캐러셀 상태 유지.
- Dart lib/test 정적 분석.
- 실제 청명역 API 검색: kakao-15110709. 사진 응답 200, 같은 사진 138,898바이트. 최초 226ms, 코스 조회 중 6ms, 재조회 6ms. 같은 시간 health 응답 6ms.
- 실제 경기 수원시 영통구 맞춤 코스 생성: 삼성 이노베이션 뮤지엄·머내생태공원·반달공원, 현재 날씨 반영. 로컬 측정 생성 444ms, 상세 재조회 7ms(외부/내부 캐시가 준비된 상태).
- Windows 브라우저 자동 UI 확인은 도구의 URL 식별 실패로 중단됐다. 실제 Android/iOS 기기의 레이아웃·권한·성능은 미검증이다.
- 최초 외부 API 응답속도·운영시간·길찾기 도로망은 보장하지 않는다. 이동 거리는 직선거리 보정 추정치로 명시한다. 카카오 실제 계정 로그인 검증은 사용자가 해야 한다.

## 실행

루트: `docker compose --env-file .env -f infra/docker-compose.yml -p tory-local up -d --build`

app: `flutter run -d chrome --web-hostname localhost --web-port 3000 --no-pub`

백엔드 테스트는 compose run에 backend 디렉터리를 /app으로 마운트하고 `RUN_DB_TESTS=1 python -m pytest -q`로 실행한다. 테스트는 실제 Redis를 쓰지 않고, PostgreSQL은 임시 schema를 생성·삭제한다.

## 참고

- Python 비동기 I/O: https://docs.python.org/3/library/asyncio-task.html#asyncio.to_thread
- Flutter route 상태: https://api.flutter.dev/flutter/widgets/ModalRoute/isCurrentOf.html
- 군산 원도심 코스 참고: https://www.korea.kr/news/customizedNewsView.do?keyType=KW02&newsId=148970469
- 영월 방문지·구간 참고: https://korean.visitkorea.or.kr/static/coalition/ganwonnr/course04.html
