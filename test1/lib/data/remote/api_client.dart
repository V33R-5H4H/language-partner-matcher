import 'dart:convert';
import 'package:http/http.dart' as http;
import '../local/local_storage.dart';

class ApiClient {
  final http.Client _client = http.Client();

  Map<String, String> _getHeaders() {
    final token = LocalStorage.instance.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String url) async {
    return await _client.get(Uri.parse(url), headers: _getHeaders());
  }

  Future<http.Response> post(String url, {Map<String, dynamic>? body}) async {
    return await _client.post(
      Uri.parse(url),
      headers: _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(String url, {Map<String, dynamic>? body}) async {
    return await _client.put(
      Uri.parse(url),
      headers: _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
