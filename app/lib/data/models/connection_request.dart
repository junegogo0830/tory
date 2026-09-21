import '../../core/utils/image_proxy.dart';

/// 연결 요청 — 수락(status="accepted")돼야 서로 메시지를 주고받을 수 있다.
/// other* 필드는 서버가 "보는 사람" 기준으로 이미 계산해서 내려준다(내
/// user_id를 몰라도 바로 목록/채팅 화면에 쓸 수 있다).
class ConnectionRequestModel {
  const ConnectionRequestModel({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.otherUserId,
    required this.otherNickname,
    this.otherProfileImageUrl,
    required this.isRequester,
    this.message,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  final int id;
  final int requesterId;
  final int recipientId;
  final int otherUserId;
  final String otherNickname;
  final String? otherProfileImageUrl;
  // true면 내가 이 요청을 보낸 쪽(요청함), false면 받은 쪽(요청받음).
  final bool isRequester;
  final String? message;
  // 'pending' | 'accepted' | 'declined'
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  factory ConnectionRequestModel.fromJson(Map<String, dynamic> json) {
    final imagePath = json['other_profile_image_url'] as String?;
    final respondedRaw = json['responded_at'] as String?;
    return ConnectionRequestModel(
      id: json['id'] as int,
      requesterId: json['requester_id'] as int,
      recipientId: json['recipient_id'] as int,
      otherUserId: json['other_user_id'] as int,
      otherNickname: json['other_nickname'] as String,
      otherProfileImageUrl: resolveStoredImageUrl(imagePath),
      isRequester: json['is_requester'] as bool,
      message: json['message'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: respondedRaw == null ? null : DateTime.parse(respondedRaw),
    );
  }
}
