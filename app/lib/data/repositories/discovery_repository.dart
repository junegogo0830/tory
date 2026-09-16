import '../api/api_client.dart';
import '../models/hometown_location.dart';
import '../models/kakao_restaurant.dart';
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

  /// 카카오맵 기반 "전국" 맛집 카드용 — 주요 도시 풀, 하루 단위 캐싱.
  Future<List<KakaoRestaurant>> getKakaoRestaurantsNationwide() async {
    final response = await _apiClient.dio.get('/api/discovery/kakao-restaurants');
    return (response.data as List)
        .map((json) => KakaoRestaurant.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 카카오맵 기반 "내 주변"(반경 5km) 맛집 — 위치에 따라 매번 새로 조회한다.
  Future<List<KakaoRestaurant>> getKakaoRestaurantsNearby({required double lat, required double lng}) async {
    final response = await _apiClient.dio.get(
      '/api/discovery/kakao-restaurants/nearby',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return (response.data as List)
        .map((json) => KakaoRestaurant.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 카카오맵 기반 "지역" 맛집 — GPS 대신 사용자가 직접 고른 7개 광역권
  /// (서울/부산/경기/대전/전라/경상/강원) 중 하나. 음식점+카페를 한 번에 모아
  /// cuisine(큰 분류)까지 붙여서 오므로, 카테고리 토글은 이 응답을 그대로
  /// 필터링해서 쓰면 된다(토글마다 다시 조회하지 않음).
  Future<List<KakaoRestaurant>> getKakaoRestaurantsByRegion(String region) async {
    final response = await _apiClient.dio.get(
      '/api/discovery/kakao-restaurants/by-region',
      queryParameters: {'region': region},
    );
    return (response.data as List)
        .map((json) => KakaoRestaurant.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 둘러보기 탭 "다른 사람들이 둘러본 골목" — 실제로 찜한 사용자 수 기준 인기 장소.
  /// 아직 아무도 안 찜했으면 빈 리스트(호출부가 큐레이션 목록으로 폴백).
  Future<List<HometownLocation>> getPopularLocations({int limit = 10}) async {
    final response = await _apiClient.dio.get(
      '/api/discovery/popular-locations',
      queryParameters: {'limit': limit},
    );
    return (response.data as List)
        .map((json) => HometownLocation.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
