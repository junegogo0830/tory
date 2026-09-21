abstract final class AppConstants {
  static const String appName = '옛길';

  /// 로컬 개발 기준 백엔드 베이스 URL. 배포 시 --dart-define으로 재정의.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// 카카오 로그인 SDK 초기화용 네이티브 앱 키.
  /// `flutter run --dart-define=KAKAO_NATIVE_APP_KEY=...`로 주입한다.
  /// Android 매니페스트의 리다이렉트 스킴도 android/local.properties의
  /// kakao.nativeAppKey 값과 반드시 동일해야 한다 (android/app/build.gradle.kts 참고).
  static const String kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

  /// 카카오 로그인 SDK 초기화용 JavaScript 키 — 웹 전용. kakao_flutter_sdk_user
  /// 2.0.1은 웹에서 로그인 메서드를 전혀 지원하지 않아, 웹은 AuthCodeClient.authorize()로
  /// 직접 카카오 인증 서버로 리다이렉트하는 방식을 쓰는데 그 client_id가 이 키다.
  /// 카카오 콘솔의 "JavaScript 키"는 카카오맵 JS SDK(backend KAKAO_MAP_JS_KEY)와
  /// 앱 하나에 동일한 값 — `flutter run --dart-define=KAKAO_JAVASCRIPT_APP_KEY=...`로
  /// 그 값을 그대로 넘긴다.
  static const String kakaoJavaScriptAppKey = String.fromEnvironment('KAKAO_JAVASCRIPT_APP_KEY');

  /// 네이버 로그인 client_id — 네이버는 Flutter SDK 없이 리다이렉트 방식만
  /// 쓰므로 앱 초기화(KakaoSdk.init 같은 것)가 필요 없고, 이 키 하나만 있으면
  /// 된다. `flutter run --dart-define=NAVER_CLIENT_ID=...`로 주입한다.
  static const String naverClientId = String.fromEnvironment('NAVER_CLIENT_ID');

  /// 카카오/네이버 로그인 버튼을 화면에 보여줄지 여부 — 코드/백엔드 엔드포인트는
  /// 둘 다 항상 남겨두고, 이 값으로만 화면 노출을 켜고 끈다. 네이버는 앱 심사용
  /// 캡처/승인 절차가 번거로워 우선 보류하고 카카오로 되돌렸다 — 각 화면이
  /// 따로 숨김 처리를 하면 하나를 빠뜨리기 쉬워(실제로 한 번 그랬다) 여기
  /// 한 곳에서만 관리한다. SocialLoginButtons 위젯 자체가 이 값을 보고
  /// SizedBox.shrink()로 스스로 숨으므로, 호출부에서 따로 if로 감쌀 필요 없다.
  static const bool showKakaoLogin = true;
  static const bool showNaverLogin = false;
}
