import '../api/api_client.dart';
import '../models/news_item.dart';

/// 장소별 그 시절 지역 뉴스 아카이브 레포지토리. 백엔드 `/api/archive`를 호출한다.
class ArchiveRepository {
  ArchiveRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<NewsItem>> getNewsByLocation(String locationId) async {
    final response = await _apiClient.dio.get('/api/archive/$locationId');
    return (response.data as List)
        .map((json) => NewsItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Claude가 웹 검색으로 찾아 종합한 "그 시절" 이야기. 찾은 게 없으면 null.
  Future<String?> getRegionStory(String locationId) async {
    final response = await _apiClient.dio.get('/api/archive/$locationId/story');
    final data = response.data;
    if (data == null) return null;
    return data['summary'] as String;
  }
}
