import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_auth/kakao_flutter_sdk_auth.dart' as kakao_auth;
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

  /// 카카오 인증 서버가 웹 로그인 완료 후 돌려보내는 주소 — 앱이 지금 떠 있는
  /// origin의 루트다. 카카오 콘솔의 "Redirect URI"에 정확히 같은 값(포트 포함)을
  /// 등록해둬야 한다.
  String get webRedirectUri => '${Uri.base.origin}/';

  /// 카카오 로그인 SDK로 카카오 토큰을 받고, 백엔드에 교환해 옛길 자체 JWT를 저장한다.
  ///
  /// kakao_flutter_sdk_user 2.0.1은 웹에서 로그인 메서드(loginWithKakaoTalk/Account/
  /// 새 동의)를 전부 지원하지 않는다(kIsWeb이면 즉시 예외) — 웹은 카카오가 안내하는
  /// 대로 AuthCodeClient.authorize()로 카카오 인증 서버로 전체 페이지 리다이렉트하고,
  /// 돌아온 뒤엔 이 메서드가 아니라 [completeKakaoWebLogin]이 이어받는다. 이 함수는
  /// 리다이렉트만 트리거하고 반환하지 않는다(페이지가 곧 떠나므로).
  Future<void> loginWithKakao() async {
    if (kIsWeb) {
      await kakao_auth.AuthCodeClient.instance.authorize(redirectUri: webRedirectUri);
      return;
    }

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

    await _exchangeAndSave('/api/auth/kakao/login', {'access_token': kakaoToken.accessToken});
  }

  /// 웹 전용 — 카카오 인증 서버가 [webRedirectUri]로 돌려보낸 `?code=...`를
  /// 백엔드로 보내 옛길 자체 JWT로 교환한다(main.dart가 앱 시작 시 이 code를
  /// 읽어 호출한다).
  Future<void> completeKakaoWebLogin(String code) async {
    await _exchangeAndSave('/api/auth/kakao/login-web', {'code': code, 'redirect_uri': webRedirectUri});
  }

  Future<void> _exchangeAndSave(String path, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post(path, data: data);
    await _tokenStorage.save(
      accessToken: response.data['access_token'] as String,
      refreshToken: response.data['refresh_token'] as String,
    );
  }

  // --- 자체 회원가입/로그인 --------------------------------------------------

  /// 회원가입 화면에서 아이디를 입력하는 동안 즉시 중복 확인용으로 쓴다.
  Future<bool> isUsernameAvailable(String username) async {
    final response = await _apiClient.dio.get(
      '/api/auth/username-available',
      queryParameters: {'username': username},
    );
    return response.data['available'] as bool;
  }

  /// 휴대폰 본인확인 1단계 — 인증번호를 문자로 보낸다(개발 환경에서 NCP SENS
  /// 키가 없으면 백엔드가 실제로 보내지 않고 로그로만 남긴다).
  Future<void> sendPhoneVerificationCode(String phoneNumber) async {
    await _apiClient.dio.post('/api/auth/phone/send-code', data: {'phone_number': phoneNumber});
  }

  /// 휴대폰 본인확인 2단계 — 성공하면 회원가입 요청에 실어 보낼 짧은 유효기간
  /// 토큰을 반환한다.
  Future<String> verifyPhoneVerificationCode(String phoneNumber, String code) async {
    final response = await _apiClient.dio.post(
      '/api/auth/phone/verify-code',
      data: {'phone_number': phoneNumber, 'code': code},
    );
    return response.data['phone_verification_token'] as String;
  }

  /// 자체 회원가입 — 약관 동의와 함께 보낸다. 성공하면 로그인 상태가 된다.
  ///
  /// 휴대폰 본인확인은 뺐다 — SMS 발송 업체가 전부 사업자 등록을 요구해서
  /// 개인 프로젝트 단계에서는 막혀 있다. [sendPhoneVerificationCode]/
  /// [verifyPhoneVerificationCode]는 나중에 업체를 구하면 다시 연결할 수
  /// 있게 그대로 남겨뒀다.
  Future<void> signup({
    required String username,
    required String password,
    required bool agreeTerms,
    required bool agreePrivacy,
    bool agreeMarketing = false,
  }) async {
    await _exchangeAndSave('/api/auth/signup', {
      'username': username,
      'password': password,
      'agree_terms': agreeTerms,
      'agree_privacy': agreePrivacy,
      'agree_marketing': agreeMarketing,
    });
  }

  Future<void> loginWithPassword(String username, String password) async {
    await _exchangeAndSave('/api/auth/login', {'username': username, 'password': password});
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
