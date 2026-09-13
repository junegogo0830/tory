import '../api/api_client.dart';
import '../models/app_notification.dart';

/// 알림 레포지토리. 백엔드 `/api/notifications`를 호출한다. 전부 로그인 필요.
class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppNotification>> list({int limit = 30, int offset = 0}) async {
    final response = await _apiClient.dio.get(
      '/api/notifications',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (response.data as List)
        .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final response = await _apiClient.dio.get('/api/notifications/unread-count');
    return response.data['count'] as int;
  }

  Future<void> markRead(int id) async {
    await _apiClient.dio.post('/api/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _apiClient.dio.post('/api/notifications/read-all');
  }

  Future<NotificationSettings> getSettings() async {
    final response = await _apiClient.dio.get('/api/notifications/settings');
    return NotificationSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<NotificationSettings> updateSettings({
    required bool notifyOnComment,
    required bool notifyOnLike,
  }) async {
    final response = await _apiClient.dio.patch(
      '/api/notifications/settings',
      data: {'notify_on_comment': notifyOnComment, 'notify_on_like': notifyOnLike},
    );
    return NotificationSettings.fromJson(response.data as Map<String, dynamic>);
  }
}
