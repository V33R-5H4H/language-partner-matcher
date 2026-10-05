import 'dart:convert';
import '../../core/constants/api_endpoints.dart';
import '../remote/api_client.dart';

class MatchRepository {
  final ApiClient _apiClient = ApiClient();

  Future<bool> enqueue(int targetLanguageId) async {
    final response = await _apiClient.post(
      ApiEndpoints.enqueueMatch,
      body: {'target_language_id': targetLanguageId},
    );
    return response.statusCode == 200;
  }

  Future<bool> cancel() async {
    final response = await _apiClient.post(ApiEndpoints.cancelMatch);
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>?> checkStatus() async {
    final response = await _apiClient.get(ApiEndpoints.matchStatus);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}
