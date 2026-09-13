import 'package:dio/dio.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

/// 카카오 로그인 실패 원인을 사람이 이해할 수 있는 한국어 문구로 바꾼다.
///
/// `AuthRepository.loginWithKakao()`가 던지는 예외는 크게 세 갈래다: 카카오 SDK
/// 자체 에러(`KakaoClientException` — 취소 등), 카카오 서버 에러(`KakaoAuthException`
/// — 플랫폼 설정 오류, 사용자가 동의 화면에서 취소 등), 우리 백엔드 통신 에러
/// (`DioException` — 네트워크 끊김, 서버 오류). 이 셋을 구분해야 "그냥 다시
/// 시도해주세요"보다 실제로 도움이 되는 안내를 줄 수 있다.
String describeKakaoLoginError(Object? error) {
  if (error is kakao.KakaoClientException) {
    if (error.reason == kakao.ClientErrorCause.cancelled) return '로그인을 취소했어요';
    return '카카오 로그인을 진행할 수 없어요. 카카오톡 앱을 확인해주세요.';
  }
  if (error is kakao.KakaoAuthException) {
    switch (error.error) {
      case kakao.AuthErrorCause.accessDenied:
        return '로그인을 취소했어요';
      case kakao.AuthErrorCause.misconfigured:
      case kakao.AuthErrorCause.invalidClient:
        return '카카오 로그인 설정에 문제가 있어요. 잠시 후 다시 시도해주세요.';
      case kakao.AuthErrorCause.serverError:
        return '카카오 서버에 일시적인 문제가 있어요. 잠시 후 다시 시도해주세요.';
      default:
        return '카카오 로그인에 실패했어요. 다시 시도해주세요.';
    }
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '네트워크 연결을 확인해주세요';
      default:
        return '서버에 연결하지 못했어요. 잠시 후 다시 시도해주세요.';
    }
  }
  return '카카오 로그인에 실패했어요. 다시 시도해주세요.';
}
