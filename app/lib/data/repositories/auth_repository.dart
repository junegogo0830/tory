import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

import '../api/api_client.dart';
import '../local/token_storage.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<bool> hasSession() async {
    final accessToken = await _tokenStorage.readAccessToken();
    return accessToken != null;
  }

  /// 카카오 로그인 SDK로 카카오 토큰을 받고, 백엔드에 교환해 옛길 자체 JWT를 저장한다.
  Future<void> loginWithKakao() async {
    kakao.OAuthToken kakaoToken;

    final kakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
    try {
      kakaoToken = kakaoTalkInstalled
          ? await kakao.UserApi.instance.loginWithKakaoTalk()
          : await kakao.UserApi.instance.loginWithKakaoAccount();
    } catch (_) {
      // 카카오톡 앱 로그인이 실패(취소 등)하면 카카오계정 웹 로그인으로 폴백.
      kakaoToken = await kakao.UserApi.instance.loginWithKakaoAccount();
    }

    final response = await _apiClient.dio.post(
      '/api/auth/kakao/login',
      data: {'access_token': kakaoToken.accessToken},
    );

    await _tokenStorage.save(
      accessToken: response.data['access_token'] as String,
      refreshToken: response.data['refresh_token'] as String,
    );
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    try {
      await kakao.UserApi.instance.logout();
    } catch (_) {
      // 카카오 세션 로그아웃 실패는 무시 — 옛길 자체 토큰은 이미 지워졌으므로
      // 우리 서비스 기준으로는 로그아웃된 상태가 맞다.
    }
  }
}
