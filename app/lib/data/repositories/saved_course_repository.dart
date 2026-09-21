import '../api/api_client.dart';
import '../models/saved_course.dart';
import '../models/tour_course.dart';

/// 코스 저장(북마크) 레포지토리. 백엔드 `/api/saved-courses`를 호출한다.
class SavedCourseRepository {
  SavedCourseRepository(this._apiClient);

  final ApiClient _apiClient;

  /// [course]를 함께 보내면(식사 추가처럼 화면에서만 반영되고 서버 캐시에는
  /// 없는 변경 포함) 백엔드가 id로 다시 조회하지 않고 이 스냅샷을 그대로
  /// 저장한다 — 안 보내면 기존처럼 id로 조회한 원본을 저장한다.
  Future<void> save({required String courseType, required String courseId, TourCourse? course}) async {
    await _apiClient.dio.post(
      '/api/saved-courses',
      data: {
        'course_type': courseType,
        'course_id': courseId,
        if (course != null) 'course': course.toJson(),
      },
    );
  }

  Future<void> unsave({required String courseType, required String courseId}) async {
    await _apiClient.dio.delete('/api/saved-courses/$courseType/$courseId');
  }

  Future<bool> status({required String courseType, required String courseId}) async {
    final response = await _apiClient.dio.get(
      '/api/saved-courses/status',
      queryParameters: {'course_type': courseType, 'course_id': courseId},
    );
    return (response.data as Map<String, dynamic>)['saved'] as bool;
  }

  Future<List<SavedCourse>> list() async {
    final response = await _apiClient.dio.get('/api/saved-courses');
    return (response.data as List)
        .map((json) => SavedCourse.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
