import '../api/api_client.dart';
import '../models/connection_request.dart';
import '../models/direct_message.dart';

/// 연결 요청/메시지 레포지토리. 백엔드 `/api/connections`를 호출한다.
class ConnectionRepository {
  ConnectionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ConnectionRequestModel> sendRequest({required int recipientId, String? message}) async {
    final response = await _apiClient.dio.post(
      '/api/connections',
      data: {'recipient_id': recipientId, 'message': message},
    );
    return ConnectionRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ConnectionRequestModel> respond(int requestId, bool accept) async {
    final response = await _apiClient.dio.post(
      '/api/connections/$requestId/respond',
      data: {'accept': accept},
    );
    return ConnectionRequestModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ConnectionRequestModel>> requests({required String direction, String? status}) async {
    final response = await _apiClient.dio.get(
      '/api/connections/requests',
      queryParameters: {'direction': direction, 'status': ?status},
    );
    return (response.data as List)
        .map((c) => ConnectionRequestModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<List<ConnectionRequestModel>> connections() async {
    final response = await _apiClient.dio.get('/api/connections');
    return (response.data as List)
        .map((c) => ConnectionRequestModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<List<DirectMessage>> messages(int connectionId, {int offset = 0}) async {
    final response = await _apiClient.dio.get(
      '/api/connections/$connectionId/messages',
      queryParameters: {'offset': offset},
    );
    return (response.data as List)
        .map((m) => DirectMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<DirectMessage> sendMessage(int connectionId, String body) async {
    final response = await _apiClient.dio.post(
      '/api/connections/$connectionId/messages',
      data: {'body': body},
    );
    return DirectMessage.fromJson(response.data as Map<String, dynamic>);
  }
}
