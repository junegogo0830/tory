import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/hometown_location.dart';
import '../models/nearby_place.dart';

/// 장소 조회 레포지토리. 백엔드 `/api/location` 엔드포인트를 호출한다.
class LocationRepository {
  LocationRepository(this._apiClient);

  final ApiClient _apiClient;

  /// 실제 "최근 둘러본 골목" 히스토리(로컬 저장) 기능이 붙기 전까지는
  /// 이 seed ID들을 백엔드에서 최신 상태로 조회해 보여준다.
  ///
  /// 'suncheon-jeonpo'는 뺐다 — 이 3곳 중 하나로 고정 노출되다 보니 매번
  /// 반복해서 뜬다는 피드백이 있었다(코스 추천 쪽 "순천만 노을 산책 코스"는
  /// 별개 기능이라 백엔드 데이터는 그대로 남아있고, 여기 캐러셀에서만 뺐다).
  static const _recentLocationIds = [
    'gunsan-jungang',
    'yeongwol-jang',
  ];

  Future<List<HometownLocation>> getRecentLocations() async {
    final locations = await Future.wait(
      _recentLocationIds.map(getLocationById),
    );
    return locations.whereType<HometownLocation>().toList();
  }

  /// 둘러보기 화면 등에서 사용하는 전체 장소 목록.
  Future<List<HometownLocation>> getAllLocations() async {
    final response = await _apiClient.dio.get('/api/location/all');
    return (response.data as List)
        .map((json) => HometownLocation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<HometownLocation?> getLocationById(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/location/$id');
      return HometownLocation.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 자유 입력(주소/학교/아파트 텍스트)에 대응하는 장소를 찾는다.
  Future<HometownLocation> resolveFromQuery(String query) async {
    final response = await _apiClient.dio.get(
      '/api/location',
      queryParameters: {'query': query},
    );
    return HometownLocation.fromJson(response.data as Map<String, dynamic>);
  }

  /// 검색창 자동완성용: 검색어에 맞는 후보를 최대 [limit]개 반환한다.
  Future<List<HometownLocation>> searchLocations(String query, {int limit = 5}) async {
    final response = await _apiClient.dio.get(
      '/api/location/search',
      queryParameters: {'query': query, 'limit': limit},
    );
    return (response.data as List)
        .map((json) => HometownLocation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<HometownLocation>> searchTourLocations(String query, {int limit = 10}) async {
    final response = await _apiClient.dio.get('/api/location/tour-search', queryParameters: {'query': query, 'limit': limit});
    return (response.data as List).map((json) => HometownLocation.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// 장소 주변 실제 음식점 목록 (좌표 없거나 매칭 없으면 빈 리스트).
  Future<List<NearbyPlace>> getNearbyRestaurants(String locationId) async {
    final response = await _apiClient.dio.get('/api/location/$locationId/nearby-restaurants');
    return (response.data as List)
        .map((json) => NearbyPlace.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
