import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../local/token_storage.dart';

/// 백엔드 FastAPI 호출용 공용 Dio 클라이언트.
/// 로그인 상태면 저장된 액세스 토큰을 자동으로 Authorization 헤더에 붙이고,
/// 401을 받으면 리프레시 토큰으로 한 번 갱신을 시도한 뒤 원 요청을 재시도한다.
class ApiClient {
  ApiClient({Dio? dio, TokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? TokenStorage(),
        dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            ) {
    this.dio.interceptors.add(
          InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
        );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;

  /// 리프레시 요청 자체는 인터셉터를 타지 않는 별도 Dio(무한루프 방지)로 보낸다.
  late final Dio _plainDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final isUnauthorized = error.response?.statusCode == 401;
    final alreadyRetried = error.requestOptions.extra['retriedAfterRefresh'] == true;

    if (!isUnauthorized || alreadyRetried) {
      handler.next(error);
      return;
    }

    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      handler.next(error);
      return;
    }

    try {
      final response = await _plainDio.post(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newAccessToken = response.data['access_token'] as String;
      await _tokenStorage.saveAccessToken(newAccessToken);

      final retryOptions = error.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      retryOptions.extra['retriedAfterRefresh'] = true;
      final retryResponse = await dio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      // 리프레시도 실패했으면 로그인 세션이 끝난 것 — 토큰을 지우고 원래 401을 그대로 전달.
      await _tokenStorage.clear();
      handler.next(error);
    }
  }
}
