import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/tour_course.dart';

/// 감성분석 결합 추천 코스 레포지토리. 백엔드 `/api/course`를 호출한다.
class CourseRepository {
  CourseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<TourCourse>> getCoursesByLocation(String locationId) async {
    final response = await _apiClient.dio.get('/api/course/by-location/$locationId');
    return _parseList(response.data);
  }

  /// 코스 탭(전체 목록)에서 사용하는 통합 리스트.
  Future<List<TourCourse>> getAllCourses() async {
    final response = await _apiClient.dio.get('/api/course');
    return _parseList(response.data);
  }

  Future<TourCourse?> getCourseById(String courseId) async {
    try {
      final response = await _apiClient.dio.get('/api/course/detail/$courseId');
      return TourCourse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  List<TourCourse> _parseList(dynamic data) {
    return (data as List)
        .map((json) => TourCourse.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
