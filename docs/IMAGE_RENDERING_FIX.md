# 화면 복귀 후 사진이 검게 표시되는 문제

## 원인과 수정

현재 SDK는 Flutter 3.47.4이며, `cached_network_image` 3.4.1의 웹 기본값은
HTML 이미지 코덱이다. 이 SDK의 `ImageElementImageSource._doClose()`는
이미지를 해제하면서 HTML 요소의 `src`를 비운다. 아직 그 이미지를 참조하는
그림이 있으면 화면 복귀나 캐시 정리 후 검게 그려질 수 있다.

동일 증상과 원인이 보고된 Flutter 이슈:
https://github.com/flutter/flutter/issues/191800

`app/lib/shared/widgets/app_network_image.dart`로 모든 사진 표시 13곳을 통합했다.

- 웹: `Image.network` + `WebHtmlElementStrategy.never`로 바이트를 디코딩한다.
- Android/iOS 등 네이티브: 기존 `CachedNetworkImage` 디스크 캐시를 유지한다.
- TourAPI 프록시 URL 변환은 공통 위젯에서 처리한다.
- 홈, 둘러보기, 맛집 목록, 코스 목록/상세, 주변 코스, 커뮤니티 목록/상세/미리보기,
  장소 비교에 적용했다. 기존 크기·색상·로딩 및 실패 UI를 유지한다.
- 비교 화면의 현재 사진에는 불필요한 투명색 multiply 필터를 적용하지 않는다.

캐시를 전부 삭제하거나 화면 이동마다 API를 다시 호출하는 방식은 사용하지 않는다.
잘못된 URL, 삭제된 원본 사진, 실제 네트워크 실패에는 기존 대체 화면이 표시된다.

## 검증 (2026-09-12)

- Dart `analyze lib test`: 문제 없음.
- 기존 Flutter 테스트 3개 통과 (청명역 검색 후 홈 복귀 포함).
- `test/app_network_image_web_test.dart`: Chrome CanvasKit에서 통과.
  - 고정 PNG를 실제 디코딩하고 표시된 픽셀 RGB/알파를 확인.
  - 화면 이동/복귀 4회 및 이미지 캐시 정리 후 원래 색상 유지.
  - 기록된 그림을 남긴 상태에서 위젯과 이미지 캐시를 해제한 뒤에도 정상 색상 유지.
- 실행 중인 API의 홈 하이라이트/맛집 사진 6개: HTTP 200, `image/jpeg`,
  CORS 허용 응답 확인.
- 실제 Android/iOS 기기에서의 실행은 이번 검증에 포함하지 않았다.

실행 명령 (app 디렉터리):

```powershell
flutter test --no-pub test/widget_test.dart
flutter test --no-pub --platform chrome test/app_network_image_web_test.dart
```

이 PC의 Flutter 웹 테스트 실행기에는 별도의 Windows 경로 문제가 있었다.
`_localCanvasKitHandler`가 Windows 경로를 `canvaskit/`와 비교하면서 로컬
CanvasKit JS/WASM 요청에 404를 반환해 테스트 시작이 멈췄다. 이번 검증에서는
테스트용 headless Chrome의 해당 두 요청에 설치된 SDK의 원본 JS/WASM 파일을
공급한 뒤 테스트 iframe을 다시 로드했다. 앱이나 SDK 소스를 변경하거나 렌더러를
대체하지 않았다. 동일 SDK/Windows에서 위 명령 실행이 멈추면 이 테스트 실행기
문제를 먼저 해결해야 한다.
