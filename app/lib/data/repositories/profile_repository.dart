import '../api/api_client.dart';
import '../models/profile.dart';

/// 로그인한 사용자의 프로필 레포지토리. 백엔드 `/api/profile`을 호출한다.
/// 모든 메서드는 인증(Authorization 헤더)이 필요하다 — ApiClient가 자동으로 붙인다.
class ProfileRepository {
  ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Profile> getProfile() async {
    final response = await _apiClient.dio.get('/api/profile');
    return Profile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> saveLocation(String locationId) async {
    await _apiClient.dio.post('/api/profile/saved-locations/$locationId');
  }

  Future<void> unsaveLocation(String locationId) async {
    await _apiClient.dio.delete('/api/profile/saved-locations/$locationId');
  }

  Future<void> completeCourse(String courseId) async {
    await _apiClient.dio.post('/api/profile/completed-courses/$courseId');
  }
}
