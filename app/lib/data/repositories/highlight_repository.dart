import '../api/api_client.dart';
import '../models/highlight_card.dart';

/// 홈 화면 카드 캐러셀 레포지토리. 백엔드 `/api/highlights`를 호출한다.
class HighlightRepository {
  HighlightRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<HighlightCard>> getHighlightCards() async {
    final response = await _apiClient.dio.get('/api/highlights');
    return (response.data as List)
        .map((json) => HighlightCard.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
