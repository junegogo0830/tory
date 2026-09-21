import 'package:dio/dio.dart';

/// 네이버 로그인 실패 원인을 사람이 이해할 수 있는 한국어 문구로 바꾼다.
///
/// 네이버는 Flutter SDK 없이 리다이렉트 방식만 쓰기 때문에(카카오처럼 별도
/// SDK 예외 타입이 없다), 우리 백엔드 통신 에러(DioException)만 구분하면 된다.
String describeNaverLoginError(Object? error) {
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
  return '네이버 로그인에 실패했어요. 다시 시도해주세요.';
}
