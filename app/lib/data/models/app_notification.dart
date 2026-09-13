/// 내 글에 달린 댓글/좋아요 알림.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.actorNickname,
    required this.postId,
    this.postTitle,
    this.commentId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  // "comment" | "like"
  final String type;
  final String actorNickname;
  final int postId;
  final String? postTitle;
  final int? commentId;
  final bool isRead;
  final DateTime createdAt;

  String get message {
    final title = postTitle?.isNotEmpty == true ? postTitle : '내 글';
    return type == 'comment'
        ? '$actorNickname님이 "$title"에 댓글을 남겼어요'
        : '$actorNickname님이 "$title"을(를) 좋아해요';
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      actorNickname: json['actor_nickname'] as String,
      postId: json['post_id'] as int,
      postTitle: json['post_title'] as String?,
      commentId: json['comment_id'] as int?,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationSettings {
  const NotificationSettings({required this.notifyOnComment, required this.notifyOnLike});

  final bool notifyOnComment;
  final bool notifyOnLike;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      notifyOnComment: json['notify_on_comment'] as bool,
      notifyOnLike: json['notify_on_like'] as bool,
    );
  }
}
