import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../api/api_client.dart';
import '../models/my_memory.dart';
import '../models/profile.dart';
import '../models/recent_course.dart';
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

  /// 첫 로그인 온보딩 완료(또는 건너뛰기) 처리 — 호출하면 다음부터 온보딩
  /// 화면이 다시 뜨지 않는다. 거주지/살았던 곳은 각각 community의
  /// setHomeRegion, 이 클래스의 saveLocation을 따로 호출해서 저장한다.
  Future<Profile> completeOnboarding({String? ageGroup}) async {
    final response = await _apiClient.dio.patch(
      '/api/profile/onboarding',
      data: {'age_group': ageGroup},
    );
    return Profile.fromJson(response.data as Map<String, dynamic>);
  }

  /// 자체 회원가입(아이디+비밀번호) 계정만 가능. 카카오 계정으로 호출하면 422.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _apiClient.dio.patch(
      '/api/profile/password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  Future<void> updateNickname(String nickname) async {
    await _apiClient.dio.patch('/api/profile/nickname', data: {'nickname': nickname});
  }

  /// "정보 수정" — 성별/이름/전화번호(전부 선택, 보낸 필드만 바뀐다).
  Future<Profile> updateInfo({String? gender, String? fullName, String? phoneNumber, bool? friendFinderEnabled}) async {
    final response = await _apiClient.dio.patch(
      '/api/profile/info',
      data: {'gender': gender, 'full_name': fullName, 'phone_number': phoneNumber, 'friend_finder_enabled': friendFinderEnabled},
    );
    return Profile.fromJson(response.data as Map<String, dynamic>);
  }

  /// 홈 "이어보기" — 마지막으로 본 코스가 없으면 null.
  Future<RecentCourse?> getRecentCourse() async {
    final response = await _apiClient.dio.get('/api/profile/recent-course');
    if (response.data == null) return null;
    return RecentCourse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 코스 상세 화면을 열 때마다 호출 — 마지막으로 본 코스를 덮어쓴다.
  Future<void> recordCourseView({required String courseType, required String courseId}) async {
    await _apiClient.dio.put(
      '/api/profile/recent-course',
      data: {'course_type': courseType, 'course_id': courseId},
    );
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
