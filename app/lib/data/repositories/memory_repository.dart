import '../api/api_client.dart';
import '../models/memory_attribute.dart';
import '../models/memory_match.dart';
import '../models/memory_profile.dart';

/// "추억 조건" 프로필/검색 레포지토리. 백엔드 `/api/memory`를 호출한다.
class MemoryRepository {
  MemoryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<MemoryAttribute> addAttribute({
    required String type,
    required String label,
    String? placeId,
    int? startYear,
    int? endYear,
  }) async {
    final response = await _apiClient.dio.post(
      '/api/memory/attributes',
      data: {
        'type': type,
        'label': label,
        'place_id': placeId,
        'start_year': startYear,
        'end_year': endYear,
      },
    );
    return MemoryAttribute.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MemoryAttribute>> myAttributes() async {
    final response = await _apiClient.dio.get('/api/memory/attributes/me');
    return (response.data as List)
        .map((a) => MemoryAttribute.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteAttribute(int attributeId) async {
    await _apiClient.dio.delete('/api/memory/attributes/$attributeId');
  }

  Future<List<MemoryMatch>> search(List<Map<String, dynamic>> filters) async {
    final response = await _apiClient.dio.post('/api/memory/search', data: {'filters': filters});
    return (response.data as List)
        .map((m) => MemoryMatch.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<MemoryProfile> profile(int userId) async {
    final response = await _apiClient.dio.get('/api/memory/profile/$userId');
    return MemoryProfile.fromJson(response.data as Map<String, dynamic>);
  }
}
