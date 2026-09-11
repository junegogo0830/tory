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
}
