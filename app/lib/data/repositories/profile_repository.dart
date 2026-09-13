import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../api/api_client.dart';
import '../models/my_memory.dart';
import '../models/profile.dart';
import '../models/tour_course.dart';

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

  /// "사진으로 남긴 추억" — 내가 쓴 글 중 사진이 있는 것만, 게시판 무관 최신순.
  Future<List<MyMemory>> getMemories({int limit = 30, int offset = 0}) async {
    final response = await _apiClient.dio.get(
      '/api/profile/memories',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (response.data as List)
        .map((json) => MyMemory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// "내가 만든 코스" — 로그인 상태로 생성한 맞춤 코스는 자동으로 여기 저장된다.
  Future<List<TourCourse>> getMyCourses({int limit = 30, int offset = 0}) async {
    final response = await _apiClient.dio.get(
      '/api/profile/courses',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (response.data as List)
        .map((json) => TourCourse.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateNickname(String nickname) async {
    await _apiClient.dio.patch('/api/profile/nickname', data: {'nickname': nickname});
  }

  Future<void> updatePhoto({
    required List<int> photoBytes,
    required String photoFilename,
    String photoMimeType = 'image/jpeg',
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        photoBytes,
        filename: photoFilename,
        contentType: MediaType.parse(photoMimeType),
      ),
    });
    await _apiClient.dio.post('/api/profile/photo', data: formData);
  }
}
