import '../../core/utils/image_proxy.dart';

/// 프로필 "사진으로 남긴 추억" — 내가 쓴 글 중 사진이 있는 것만.
class MyMemory {
  const MyMemory({
    required this.id,
    required this.region,
    required this.board,
    this.title,
    required this.photoUrl,
    this.caption,
    this.memoryYear,
    required this.createdAt,
  });

  final int id;
  final String region;
  final String board;
  final String? title;
  final String photoUrl;
  final String? caption;
  final int? memoryYear;
  final DateTime createdAt;

  factory MyMemory.fromJson(Map<String, dynamic> json) {
    return MyMemory(
      id: json['id'] as int,
      region: json['region'] as String,
      board: json['board'] as String,
      title: json['title'] as String?,
      photoUrl: resolveStoredImageUrl(json['photo_url'] as String)!,
      caption: json['caption'] as String?,
      memoryYear: json['memory_year'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
