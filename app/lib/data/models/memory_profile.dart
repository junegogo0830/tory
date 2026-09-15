import '../../core/constants/app_constants.dart';
import 'memory_attribute.dart';

/// "추억 프로필" — 본인이면 속성 편집이, 타인이면 연결 상태에 따른 액션이 갈린다.
class MemoryProfile {
  const MemoryProfile({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
    required this.attributes,
    required this.courseCount,
    required this.memoryPostCount,
    required this.isMine,
    required this.connectionStatus,
    this.connectionId,
  });

  final int userId;
  final String nickname;
  final String? profileImageUrl;
  final List<MemoryAttribute> attributes;
  final int courseCount;
  final int memoryPostCount;
  final bool isMine;
  // 'none' | 'pending_sent' | 'pending_received' | 'accepted'
  final String connectionStatus;
  final int? connectionId;

  factory MemoryProfile.fromJson(Map<String, dynamic> json) {
    final imagePath = json['profile_image_url'] as String?;
    return MemoryProfile(
      userId: json['user_id'] as int,
      nickname: json['nickname'] as String,
      profileImageUrl: imagePath == null ? null : '${AppConstants.apiBaseUrl}$imagePath',
      attributes: (json['attributes'] as List)
          .map((a) => MemoryAttribute.fromJson(a as Map<String, dynamic>))
          .toList(),
      courseCount: json['course_count'] as int,
      memoryPostCount: json['memory_post_count'] as int,
      isMine: json['is_mine'] as bool,
      connectionStatus: json['connection_status'] as String,
      connectionId: json['connection_id'] as int?,
    );
  }
}
