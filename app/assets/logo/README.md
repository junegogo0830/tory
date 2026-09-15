# 로고/일러스트 에셋

실제 파일:

- `logo.png` — 풀 로고(아이콘 뱃지 + "옛길" 글자, 세로 배치). 참고/원본용.
- `logo_icon.png` — `logo.png`에서 아이콘 뱃지 부분만 잘라낸 정사각형 이미지. `YetgilMark`(헤더·소개 화면·웹 로딩 화면)가 쓴다.
- `logo_wordmark.png` — `logo.png`에서 "옛길" 글자 부분만 잘라낸 이미지. `YetgilWordmark`(옛길 게시판 카드·웹 로딩 화면)가 쓴다.
- `login.png` — 로그인 전 커뮤니티/프로필 화면에 쓰는 인사 일러스트(이웃 세 명 + "추억을 함께 나눠요!"). `NeighborsGreetingIllustration`이 쓴다.
- `community.png` — 홈 화면 "내 동네 커뮤니티에 가입해보세요" 카드 오른쪽에 페이드로 걸리는 배경 사진. `CardFadeArt`가 쓴다.
- `nearby_attractions.png` — 홈 화면 "내 주변 관광지" 카드 오른쪽에 페이드로 걸리는 배경 사진. `CardFadeArt`가 쓴다.

`logo_icon.png`/`logo_wordmark.png`는 `logo.png`에서 잘라낸 파생 파일이라, `logo.png`를 새로 받으면 두 파일도 다시 잘라내야 한다(PIL로 배경색과 다른 픽셀의 bounding box를 찾아 크롭).
