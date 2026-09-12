import '../api/api_client.dart';
import '../models/weather_info.dart';

/// 현재 날씨 레포지토리. 백엔드 `/api/weather`를 호출한다.
class WeatherRepository {
  WeatherRepository(this._apiClient);

  final ApiClient _apiClient;

  /// 키가 없거나 조회 실패 시 null — 호출부가 날씨 무관 기본값으로 폴백한다.
  Future<WeatherInfo?> getCurrentWeather({required double lat, required double lng}) async {
    final response = await _apiClient.dio.get(
      '/api/weather/current',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    final data = response.data;
    if (data == null) return null;
    return WeatherInfo.fromJson(data as Map<String, dynamic>);
  }
}
