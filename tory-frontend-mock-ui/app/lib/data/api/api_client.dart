import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';

/// 백엔드 FastAPI 호출용 공용 Dio 클라이언트.
/// 레포지토리들이 목 데이터 대신 실제 API로 전환할 때 이 클라이언트를 주입해 사용한다.
class ApiClient {
  ApiClient({Dio? dio})
      : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  final Dio dio;
}
