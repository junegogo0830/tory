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
}
