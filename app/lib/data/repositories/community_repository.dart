import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../api/api_client.dart';
import '../models/community_post.dart';
import '../models/neighbor.dart';
import '../models/pending_photo.dart';

/// 커뮤니티(동네 게시판) 레포지토리. 백엔드 `/api/community`를 호출한다.
class CommunityRepository {
  CommunityRepository(this._apiClient);

  final ApiClient _apiClient;
  Future<Map<String, dynamic>> getDetail(int id) async =>
      (await _apiClient.dio.get('/api/community/posts/$id')).data
          as Map<String, dynamic>;
  Future<List<Map<String, dynamic>>> comments(int id, {int offset = 0}) async =>
      ((await _apiClient.dio.get(
                '/api/community/posts/$id/comments',
                queryParameters: {'offset': offset},
              )).data
              as List)
          .cast<Map<String, dynamic>>();
  Future<void> comment(int id, String body, {int? parentId}) async {
    await _apiClient.dio.post(
      '/api/community/posts/$id/comments',
      data: {'body': body, 'parent_id': ?parentId},
    );
  }

  Future<void> deleteComment(int id, int commentId) async {
    await _apiClient.dio.delete('/api/community/posts/$id/comments/$commentId');
  }

  Future<void> setLike(int id, bool liked) async {
    if (liked) {
      await _apiClient.dio.put('/api/community/posts/$id/like');
    } else {
      await _apiClient.dio.delete('/api/community/posts/$id/like');
    }
  }

  Future<void> update(int id, String title, String caption) async {
    await _apiClient.dio.patch(
      '/api/community/posts/$id',
      data: {'title': title, 'caption': caption},
    );
  }

  Future<void> delete(int id) async {
    await _apiClient.dio.delete('/api/community/posts/$id');
  }

  /// 좌표로 시군구 지역명을 찾는다 (역지오코딩). 실패하면 null.
  Future<String?> regionByCoords({
    required double lat,
    required double lng,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/community/region-by-coords',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return response.data['region'] as String?;
  }

  /// 로그인 필요. "내 동네"를 설정/변경한다.
  Future<void> setHomeRegion(String region) async {
    await _apiClient.dio.patch(
      '/api/community/home-region',
      data: {'region': region},
    );
  }

  Future<List<CommunityPost>> getPosts(
    String region, {
    required String board,
    int limit = 20,
    int offset = 0,
    String query = '',
  }) async {
    final response = await _apiClient.dio.get(
      '/api/community/posts',
      queryParameters: {
        'region': region,
        'board': board,
        'limit': limit,
        'offset': offset,
        'query': query,
      },
    );
    return (response.data as List)
        .map((json) => CommunityPost.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 로그인 필요. 지역 게시판에 글을 올린다 — 사진은 게시판에 따라 선택(자유/주민/
  /// 관광정보)이거나 사실상 필수(추억)고, 최대 5장까지 첨부할 수 있다.
  Future<CommunityPost> createPost({
    required String region,
    required String board,
    String? title,
    List<PendingPhoto> photos = const [],
    String? locationId,
    String? caption,
    int? memoryYear,
  }) async {
    final formData = FormData.fromMap({
      'region': region,
      'board': board,
      if (title != null && title.isNotEmpty) 'title': title,
      'location_id': ?locationId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'memory_year': ?memoryYear,
      if (photos.isNotEmpty)
        'files': [
          for (final photo in photos)
            MultipartFile.fromBytes(
              photo.bytes,
              filename: photo.filename,
              contentType: MediaType.parse(photo.mimeType),
            ),
        ],
    });
    final response = await _apiClient.dio.post(
      '/api/community/posts',
      data: formData,
    );
    return CommunityPost.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> reportPost(int postId, String reason) async {
    await _apiClient.dio.post('/api/community/posts/$postId/report', data: {'reason': reason});
  }

  Future<void> reportComment(int postId, int commentId, String reason) async {
    await _apiClient.dio.post(
      '/api/community/posts/$postId/comments/$commentId/report',
      data: {'reason': reason},
    );
  }

  Future<void> blockUser(int userId) async {
    await _apiClient.dio.post('/api/community/users/$userId/block');
  }

  Future<void> unblockUser(int userId) async {
    await _apiClient.dio.delete('/api/community/users/$userId/block');
  }

  Future<List<BlockedUser>> blockedUsers() async {
    final response = await _apiClient.dio.get('/api/community/blocked-users');
    return (response.data as List)
        .map((json) => BlockedUser.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// "친구찾기" — 같은 "내 동네"로 설정한 다른 사용자들, 그 동네 게시글 수 많은 순.
  Future<List<Neighbor>> neighbors(String region) async {
    final response = await _apiClient.dio.get(
      '/api/community/neighbors',
      queryParameters: {'region': region},
    );
    return (response.data as List)
        .map((json) => Neighbor.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 이웃을 눌렀을 때 — 그 사람이 이 동네에 쓴 글(게시판 무관).
  Future<List<CommunityPost>> postsByUser(
    int authorId, {
    required String region,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/community/users/$authorId/posts',
      queryParameters: {'region': region, 'limit': limit, 'offset': offset},
    );
    return (response.data as List)
        .map((json) => CommunityPost.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
