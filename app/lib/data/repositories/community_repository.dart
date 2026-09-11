import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../api/api_client.dart';
import '../models/community_post.dart';

/// 커뮤니티(동네 추억) 레포지토리. 백엔드 `/api/community`를 호출한다.
class CommunityRepository {
  CommunityRepository(this._apiClient);

  final ApiClient _apiClient;

  /// 좌표로 시군구 지역명을 찾는다 (역지오코딩). 실패하면 null.
  Future<String?> regionByCoords({required double lat, required double lng}) async {
    final response = await _apiClient.dio.get(
      '/api/community/region-by-coords',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return response.data['region'] as String?;
  }

  /// 로그인 필요. "내 동네"를 설정/변경한다.
  Future<void> setHomeRegion(String region) async {
    await _apiClient.dio.patch('/api/community/home-region', data: {'region': region});
  }

  Future<List<CommunityPost>> getPosts(String region, {int limit = 20, int offset = 0}) async {
    final response = await _apiClient.dio.get(
      '/api/community/posts',
      queryParameters: {'region': region, 'limit': limit, 'offset': offset},
    );
    return (response.data as List)
        .map((json) => CommunityPost.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 로그인 필요. 사진 한 장으로 "추억"을 등록한다.
  ///
  /// 바이트로 받는 이유: `MultipartFile.fromFile`은 `dart:io`를 쓰기 때문에 웹
  /// 빌드에선 동작하지 않는다 — `XFile.readAsBytes()`로 읽은 바이트를 넘기면
  /// 웹/네이티브 어디서나 동일하게 동작한다.
  Future<CommunityPost> createPost({
    required String region,
    required List<int> photoBytes,
    required String photoFilename,
    String photoMimeType = 'image/jpeg',
    String? locationId,
    String? caption,
    int? memoryYear,
  }) async {
    final formData = FormData.fromMap({
      'region': region,
      'location_id': ?locationId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'memory_year': ?memoryYear,
      'file': MultipartFile.fromBytes(
        photoBytes,
        filename: photoFilename,
        contentType: MediaType.parse(photoMimeType),
      ),
    });
    final response = await _apiClient.dio.post('/api/community/posts', data: formData);
    return CommunityPost.fromJson(response.data as Map<String, dynamic>);
  }
}
