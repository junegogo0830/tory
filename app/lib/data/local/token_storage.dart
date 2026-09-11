import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 옛길 자체 JWT(access/refresh)를 기기 보안 저장소에 보관한다.
/// 카카오 SDK가 발급하는 카카오 토큰과는 별개다 — 로그인 성공 후
/// 백엔드가 내려준 우리 서비스 전용 토큰만 여기 저장한다.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'yetgil_access_token';
  static const _refreshTokenKey = 'yetgil_refresh_token';

  Future<void> save({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveAccessToken(String accessToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
