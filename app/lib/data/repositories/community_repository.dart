import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../api/api_client.dart';
import '../models/community_post.dart';
import '../models/neighbor.dart';
import '../models/pending_photo.dart';
import '../models/region_stats.dart';
import '../models/school_search_result.dart';

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

  /// 로그인 필요. "지금 보고 있는" 동네를 설정/전환한다 — 처음 가입하는
  /// 지역이면 가입 이력([myRegions]에 나올 목록)에도 함께 남는다.
  Future<void> setHomeRegion(String region) async {
    await _apiClient.dio.patch(
      '/api/community/home-region',
      data: {'region': region},
    );
  }

  /// 로그인 필요. 내가 가입한 모든 동네(최근 가입 순) — 커뮤니티 탭 지역 토글에 쓴다.
  Future<List<String>> myRegions() async {
    final response = await _apiClient.dio.get('/api/community/my-regions');
    return (response.data as List).cast<String>();
  }

  /// 새 지역 가입 확인 화면에 보여줄 통계(이미 함께하는 이웃 수, 게시글 수).
  Future<RegionStats> regionStats(String region) async {
    final response = await _apiClient.dio.get(
      '/api/community/region-stats',
      queryParameters: {'region': region},
    );
    return RegionStats.fromJson(response.data as Map<String, dynamic>);
  }

  /// 로그인 필요. 주민 게시판(중고거래) 글의 거래 상태를 바꾼다 — 작성자만 가능.
  Future<void> updateTradeStatus(int postId, String tradeStatus) async {
    await _apiClient.dio.patch(
      '/api/community/posts/$postId/trade-status',
      data: {'trade_status': tradeStatus},
    );
  }

  /// region이 null이면 로그인/지역 선택 없이도 볼 수 있는 전체(지역 무관)
  /// 피드를 준다 — 옛길 게시판은 항상 뭔가 보여야 한다는 요구사항 때문.
  Future<List<CommunityPost>> getPosts(
    String? region, {
    required String board,
    int limit = 20,
    int offset = 0,
    String query = '',
  }) async {
    final response = await _apiClient.dio.get(
      '/api/community/posts',
      queryParameters: {
        if (region != null) 'region': region,
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
  /// 관광정보)이거나 사실상 필수(추억)고, 최대 5장까지 첨부할 수 있다. 타임캡슐
  /// 게시판은 [revealAt](미래 날짜)이 필수다.
  Future<CommunityPost> createPost({
    required String region,
    required String board,
    String? title,
    List<PendingPhoto> photos = const [],
    String? locationId,
    String? caption,
    int? memoryYear,
    DateTime? revealAt,
    int? price,
    String? tradeStatus,
    bool isTrade = true,
    String? contentBlocks,
  }) async {
    final formData = FormData.fromMap({
      'region': region,
      'board': board,
      if (title != null && title.isNotEmpty) 'title': title,
      'location_id': ?locationId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      'memory_year': ?memoryYear,
      if (revealAt != null) 'reveal_at': revealAt.toUtc().toIso8601String(),
      'price': ?price,
      'trade_status': ?tradeStatus,
      'is_trade': isTrade.toString(),
      'content_blocks': ?contentBlocks,
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
    String? region,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/api/community/users/$authorId/posts',
      queryParameters: {'region': ?region, 'limit': limit, 'offset': offset},
    );
    return (response.data as List)
        .map((json) => CommunityPost.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 장소별 추억 타임라인 — 연도순으로 한 번에 가져온다(더보기 없음).
  Future<List<CommunityPost>> getTimeline(String region, {String board = 'memory'}) async {
    final response = await _apiClient.dio.get(
      '/api/community/posts/timeline',
      queryParameters: {'region': region, 'board': board},
    );
    return (response.data as List)
        .map((json) => CommunityPost.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 모교 검색 — 카카오 장소 검색으로 학교 이름을 찾는다.
  Future<List<SchoolSearchResult>> searchSchools(String query) async {
    final response = await _apiClient.dio.get(
      '/api/community/schools',
      queryParameters: {'query': query},
    );
    return (response.data as List)
        .map((json) => SchoolSearchResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// "동창찾기" — home_region 개념이 없는 스코프(학교 등)에서, 그 지역에 실제로
  /// 글을 쓴 사람들을 글 수 순으로 보여준다. 로그인 필요.
  Future<List<Neighbor>> activeAuthors(String region) async {
    final response = await _apiClient.dio.get(
      '/api/community/active-authors',
      queryParameters: {'region': region},
    );
    return (response.data as List)
        .map((json) => Neighbor.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
