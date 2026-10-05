import 'dart:convert';
import '../../core/constants/api_endpoints.dart';
import '../../models/user_model.dart';
import '../local/local_storage.dart';
import '../remote/api_client.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<UserModel?> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      final userJson = data['user'];
      final user = UserModel.fromJson(userJson);
      await LocalStorage.instance.saveAuthToken(token, user.userId);
      return user;
    }
    return null;
  }

  Future<UserModel?> register(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      body: payload,
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      final userJson = data['user'];
      final user = UserModel.fromJson(userJson);
      await LocalStorage.instance.saveAuthToken(token, user.userId);
      return user;
    }
    return null;
  }
}
