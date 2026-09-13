import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/tour_course.dart';

/// 감성분석 결합 추천 코스 레포지토리. 백엔드 `/api/course`를 호출한다.
class CourseRepository {
  CourseRepository(this._apiClient);

  final ApiClient _apiClient;
  final Map<String, TourCourse> _generated = {};

  Future<TourCourse> generate(
    Map<String, dynamic> preferences, {
    CancelToken? cancelToken,
  }) async {
    final response = await _apiClient.dio.post(
      '/api/course/generate',
      data: preferences,
      cancelToken: cancelToken,
      options: Options(receiveTimeout: const Duration(seconds: 22)),
    );
    final course = TourCourse.fromJson(response.data as Map<String, dynamic>);
    _generated[course.id] = course;
    return course;
  }

  Future<List<TourCourse>> getCoursesByLocation(String locationId) async {
    final response = await _apiClient.dio.get(
      '/api/course/by-location/$locationId',
    );
    return _parseList(response.data);
  }

  /// 코스 탭(전체 목록)에서 사용하는 통합 리스트.
  Future<List<TourCourse>> getAllCourses() async {
    final response = await _apiClient.dio.get('/api/course');
    return _parseList(response.data);
  }

  Future<TourCourse?> getCourseById(String courseId) async {
    if (_generated.containsKey(courseId)) return _generated[courseId];
    try {
      final response = await _apiClient.dio.get('/api/course/detail/$courseId');
      return TourCourse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// "현재 위치" 기반 코스. 등록된 장소가 아니어도 좌표만으로 생성된다.
  /// 주변 후보가 부족하면(콜드스팟 등) null.
  Future<TourCourse?> getCourseByCoords({
    required double lat,
    required double lng,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/course/nearby',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    final data = response.data;
    if (data == null) return null;
    return TourCourse.fromJson(data as Map<String, dynamic>);
  }

  List<TourCourse> _parseList(dynamic data) {
    return (data as List)
        .map((json) => TourCourse.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
