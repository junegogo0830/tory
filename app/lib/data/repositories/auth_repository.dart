import 'package:flutter/foundation.dart';
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
    } catch (e) {
      // 카카오톡 앱 로그인이 실패(취소 등)하면 카카오계정 웹 로그인으로 폴백.
      debugPrint('카카오톡 로그인 실패, 계정 로그인으로 폴백: $e');
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

  /// 회원 탈퇴 — 옛길 계정과 관련 데이터를 먼저 지운 뒤, 카카오 쪽 연결도 끊는다
  /// (연결까지 끊어야 다음에 "카카오로 시작하기"를 누르면 동의 화면부터 새로
  /// 시작한다 — 그냥 로그아웃만 하면 이전 동의가 남아있어 바로 재로그인된다).
  Future<void> deleteAccount() async {
    await _apiClient.dio.delete('/api/profile');
    await _tokenStorage.clear();
    try {
      await kakao.UserApi.instance.unlink();
    } catch (_) {
      // 카카오 쪽 연결 해제 실패는 무시 — 옛길 자체 계정은 이미 삭제됐다.
    }
  }
}
