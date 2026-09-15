import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../api/api_client.dart';
import '../models/custom_course.dart';
import '../models/memory_match.dart';

/// 사용자가 직접 만드는 "코스 커스텀" 레포지토리. 백엔드 `/api/custom-courses`를 호출한다.
class CustomCourseRepository {
  CustomCourseRepository(this._apiClient);

  final ApiClient _apiClient;

  /// 코스 장소에 직접 사진을 등록할 때 — 업로드 후 받은 url을 place.imageUrl로 쓴다.
  Future<String> uploadPhoto({required Uint8List bytes, required String filename, required String mimeType}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: MediaType.parse(mimeType)),
    });
    final response = await _apiClient.dio.post('/api/custom-courses/photos', data: formData);
    return (response.data as Map<String, dynamic>)['url'] as String;
  }

  /// 로그인 필요.
  Future<CustomCourse> create({
    required String title,
    required String category,
    String? description,
    required List<CustomCoursePlace> places,
    bool isPublic = true,
  }) async {
    final response = await _apiClient.dio.post(
      '/api/custom-courses',
      data: {
        'title': title,
        'category': category,
        'description': description,
        'places': places.map((p) => p.toJson()).toList(),
        'is_public': isPublic,
      },
    );
    return CustomCourse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CustomCourseSummary>> list({
    String? category,
    String sort = 'recent',
    int limit = 20,
    int offset = 0,
    // true면 로그인한 내가 만든 코스만 — "코스 공유" 작성 화면의 "내 코스에서
    // 가져오기"가 쓴다. 로그인 필요.
    bool mine = false,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/custom-courses',
      queryParameters: {
        'category': ?category,
        'sort': sort,
        'limit': limit,
        'offset': offset,
        if (mine) 'mine': true,
      },
    );
    return (response.data as List)
        .map((json) => CustomCourseSummary.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 그 사람의 공개 코스만(비공개 제외) — 추억 프로필의 "만든 코스" 섹션이 쓴다.
  Future<List<CustomCourseSummary>> listByAuthor(int authorId, {int limit = 10}) async {
    final response = await _apiClient.dio.get(
      '/api/custom-courses/by-author/$authorId',
      queryParameters: {'limit': limit},
    );
    return (response.data as List)
        .map((json) => CustomCourseSummary.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 이 코스와 추억(학교/동네/자주 간 장소)이 겹치는 사람 목록.
  Future<List<MemoryMatch>> memoryOverlap(int courseId) async {
    final response = await _apiClient.dio.get('/api/custom-courses/$courseId/memory-overlap');
    final data = response.data as Map<String, dynamic>;
    return (data['matches'] as List)
        .map((m) => MemoryMatch.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<CustomCourse> getById(int id) async {
    final response = await _apiClient.dio.get('/api/custom-courses/$id');
    return CustomCourse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 로그인 필요. 작성자만 가능 — 아니면 403. 전체 필드를 통째로 교체한다.
  Future<CustomCourse> update({
    required int id,
    required String title,
    required String category,
    String? description,
    required List<CustomCoursePlace> places,
    bool isPublic = true,
  }) async {
    final response = await _apiClient.dio.patch(
      '/api/custom-courses/$id',
      data: {
        'title': title,
        'category': category,
        'description': description,
        'places': places.map((p) => p.toJson()).toList(),
        'is_public': isPublic,
      },
    );
    return CustomCourse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 로그인 필요. 작성자만 가능 — 아니면 403.
  Future<void> delete(int id) async {
    await _apiClient.dio.delete('/api/custom-courses/$id');
  }

  /// 로그인 필요. value: 1(추천)/-1(비추천)/0(취소). 갱신된 코스를 돌려준다.
  Future<CustomCourse> vote(int id, int value) async {
    final response = await _apiClient.dio.post(
      '/api/custom-courses/$id/vote',
      data: {'value': value},
    );
    return CustomCourse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CustomCourseComment>> comments(int id) async {
    final response = await _apiClient.dio.get('/api/custom-courses/$id/comments');
    return (response.data as List)
        .map((json) => CustomCourseComment.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 로그인 필요.
  Future<CustomCourseComment> addComment(int id, String body) async {
    final response = await _apiClient.dio.post(
      '/api/custom-courses/$id/comments',
      data: {'body': body},
    );
    return CustomCourseComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteComment(int id, int commentId) async {
    await _apiClient.dio.delete('/api/custom-courses/$id/comments/$commentId');
  }

  /// 코스 커스텀에서 "카카오맵 기반"으로 장소를 검색한다.
  Future<List<KakaoPlaceSearchResult>> searchKakaoPlaces(String query) async {
    final response = await _apiClient.dio.get(
      '/api/location/kakao-search',
      queryParameters: {'query': query},
    );
    return (response.data as List)
        .map((json) => KakaoPlaceSearchResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
