import '../api/api_client.dart';
import '../models/chatbot_message.dart';

/// 훈장님 챗봇(구글 제미나이) 레포지토리. 백엔드 `/api/chatbot/message`를 호출한다.
class ChatbotRepository {
  ChatbotRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<String> sendMessage({
    required String mode,
    required List<ChatbotMessage> history,
    required String message,
  }) async {
    final response = await _apiClient.dio.post(
      '/api/chatbot/message',
      data: {
        'mode': mode,
        'history': history.map((m) => {'role': m.role, 'text': m.text}).toList(),
        'message': message,
      },
    );
    return (response.data as Map<String, dynamic>)['reply'] as String;
  }
}
