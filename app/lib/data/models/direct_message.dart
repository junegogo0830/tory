/// 연결된 두 사용자 사이의 메시지 하나. 실시간 소켓이 아니라 폴링(화면 진입
/// 시 조회 + 전송 후 재조회)으로 주고받는다.
class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.connectionId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  final int id;
  final int connectionId;
  final int senderId;
  final String body;
  final DateTime createdAt;
  final bool isMine;

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as int,
      connectionId: json['connection_id'] as int,
      senderId: json['sender_id'] as int,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool? ?? false,
    );
  }
}
