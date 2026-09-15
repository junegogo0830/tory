import 'package:dio/dio.dart';

/// 자체 회원가입/로그인 실패 원인을 사람이 이해할 수 있는 문구로 바꾼다.
///
/// 이 경로의 백엔드 에러는(kakao_login_error.dart의 카카오 SDK 에러와 달리)
/// 이미 한국어 안내문을 `detail`에 실어 보내므로(예: "이미 사용 중인 아이디예요"),
/// 그걸 그대로 보여주는 게 가장 정확하다 — 네트워크 자체가 끊긴 경우에만 자체
/// 문구로 대체한다.
String describeAuthError(Object? error) {
  if (error is DioException) {
    final data = error.response?.data;
    final detail = data is Map ? data['detail'] : null;
    if (detail is String && detail.isNotEmpty) return detail;

    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '네트워크 연결을 확인해주세요';
      default:
        return '요청을 처리하지 못했어요. 다시 시도해주세요.';
    }
  }
  return '요청을 처리하지 못했어요. 다시 시도해주세요.';
}
