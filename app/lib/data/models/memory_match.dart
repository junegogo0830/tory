import '../../core/utils/image_proxy.dart';

/// 추억 조건이 겹치는 사람 하나 — 친구 찾기 검색 결과와 코스의 "겹치는 사람"
/// 목록이 둘 다 이 모양을 쓴다.
class MemoryMatch {
  const MemoryMatch({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
    required this.score,
    required this.reasons,
  });

  final int userId;
  final String nickname;
  final String? profileImageUrl;
  final int score;
  final List<String> reasons;

  factory MemoryMatch.fromJson(Map<String, dynamic> json) {
    final imagePath = json['profile_image_url'] as String?;
    return MemoryMatch(
      userId: json['user_id'] as int,
      nickname: json['nickname'] as String,
      profileImageUrl: resolveStoredImageUrl(imagePath),
      score: json['score'] as int,
      reasons: (json['reasons'] as List).cast<String>(),
    );
  }
}
