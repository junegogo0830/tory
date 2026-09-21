/// 챗봇 대화 한 마디. role은 백엔드/제미나이 규격 그대로 "user" | "model".
class ChatbotMessage {
  const ChatbotMessage({required this.role, required this.text});

  final String role;
  final String text;

  bool get isUser => role == 'user';
}
