/// "친구찾기" — 같은 "내 동네"로 설정한 다른 사용자.
class Neighbor {
  const Neighbor({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
    required this.postCount,
  });

  final int userId;
  final String nickname;
  final String? profileImageUrl;
  final int postCount;

  factory Neighbor.fromJson(Map<String, dynamic> json) {
    return Neighbor(
      userId: json['user_id'] as int,
      nickname: json['nickname'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      postCount: json['post_count'] as int,
    );
  }
}

class BlockedUser {
  const BlockedUser({required this.userId, required this.nickname});

  final int userId;
  final String nickname;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(userId: json['user_id'] as int, nickname: json['nickname'] as String);
  }
}
