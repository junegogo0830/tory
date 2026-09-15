import '../api/api_client.dart';
import '../models/saved_course.dart';

/// 코스 저장(북마크) 레포지토리. 백엔드 `/api/saved-courses`를 호출한다.
class SavedCourseRepository {
  SavedCourseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> save({required String courseType, required String courseId}) async {
    await _apiClient.dio.post(
      '/api/saved-courses',
      data: {'course_type': courseType, 'course_id': courseId},
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
