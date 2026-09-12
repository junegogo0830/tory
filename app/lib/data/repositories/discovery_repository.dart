import '../api/api_client.dart';
import '../models/restaurant_category.dart';
import '../models/top_attraction.dart';

/// 홈 화면 발견 콘텐츠 레포지토리. 백엔드 `/api/discovery`를 호출한다.
class DiscoveryRepository {
  DiscoveryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<TopAttraction>> getTopAttractions() async {
    final response = await _apiClient.dio.get('/api/discovery/top-attractions');
    return (response.data as List)
        .map((json) => TopAttraction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<RestaurantCategory>> getRestaurantCategories() async {
    final response = await _apiClient.dio.get('/api/discovery/restaurant-categories');
    return (response.data as List)
        .map((json) => RestaurantCategory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// "자세히보기"로 들어가는 카테고리 전체 목록.
  Future<List<RestaurantItem>> getRestaurantsByCategory(String category) async {
    final response = await _apiClient.dio.get(
      '/api/discovery/restaurants',
      queryParameters: {'category': category},
    );
    return (response.data as List)
        .map((json) => RestaurantItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 현재 위치 기반 주변 맛집 — 카테고리 무관, 매번 새로 조회한다.
  Future<List<RestaurantItem>> getRestaurantsNearby({required double lat, required double lng}) async {
    final response = await _apiClient.dio.get(
      '/api/discovery/restaurants/nearby',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return (response.data as List)
        .map((json) => RestaurantItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
