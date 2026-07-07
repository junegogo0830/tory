abstract final class AppConstants {
  static const String appName = '옛길';

  /// 로컬 개발 기준 백엔드 베이스 URL. 배포 시 --dart-define으로 재정의.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
