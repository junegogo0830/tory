import '../../core/constants/app_constants.dart';

/// 커뮤니티 탭/장소 상세 화면에서 사용자가 직접 올린 "그 시절 추억" 사진 게시물.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorNickname,
    required this.region,
    required this.photoUrl,
    this.locationId,
    this.caption,
    this.memoryYear,
    required this.createdAt,
  });

  final int id;
  final String authorNickname;
  final String region;
  final String? locationId;
  // 백엔드가 상대경로("/uploads/community/xxx.jpg")로 내려주므로 여기서 절대 URL로 만든다.
  final String photoUrl;
  final String? caption;
  final int? memoryYear;
  final DateTime createdAt;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] as int,
      authorNickname: json['author_nickname'] as String,
      region: json['region'] as String,
      locationId: json['location_id'] as String?,
      photoUrl: '${AppConstants.apiBaseUrl}${json['photo_url']}',
      caption: json['caption'] as String?,
      memoryYear: json['memory_year'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
