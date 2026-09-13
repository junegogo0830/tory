import '../../core/constants/app_constants.dart';

/// 커뮤니티 탭/장소 상세 화면에서 사용자가 직접 올린 게시물. 지역(region) +
/// 게시판(board) 조합이 하나의 "게시판" 단위 — 자유/추억/주민/관광정보 4개가
/// 지역구마다 별도로 운영된다.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorNickname,
    required this.region,
    required this.board,
    this.title,
    this.photoUrl,
    this.photoUrls = const [],
    this.locationId,
    this.caption,
    this.memoryYear,
    required this.createdAt,
  });

  final int id;
  final int authorId;
  final String authorNickname;
  final String region;
  final String board;
  final String? title;
  final String? locationId;
  // 백엔드가 상대경로("/uploads/community/xxx.jpg")로 내려주므로 여기서 절대 URL로 만든다.
  // 자유/주민/관광정보 게시판은 사진 없이 글만 올릴 수 있어 null일 수 있다.
  final String? photoUrl;
  // 전체 사진(여러 장 지원) — 목록 카드는 photoUrl(대표 사진) 하나만 쓰고,
  // 상세 화면 갤러리에서 이 전체 목록을 보여준다.
  final List<String> photoUrls;
  final String? caption;
  final int? memoryYear;
  final DateTime createdAt;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final photoPath = json['photo_url'] as String?;
    final photoPaths = (json['photo_urls'] as List? ?? []).cast<String>();
    return CommunityPost(
      id: json['id'] as int,
      authorId: json['author_id'] as int,
      authorNickname: json['author_nickname'] as String,
      region: json['region'] as String,
      board: json['board'] as String,
      title: json['title'] as String?,
      locationId: json['location_id'] as String?,
      photoUrl: photoPath == null ? null : '${AppConstants.apiBaseUrl}$photoPath',
      photoUrls: photoPaths.map((path) => '${AppConstants.apiBaseUrl}$path').toList(),
      caption: json['caption'] as String?,
      memoryYear: json['memory_year'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
