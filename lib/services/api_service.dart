import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kAppUrl = 'https://review.heltog.com';
const String kApiBase = '$kAppUrl/api';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const _tokenKey = 'sanctum_token';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await readToken();
      if (token == null) {
        throw ApiException('Login nahi hai');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final res = await http.post(
      Uri.parse('$kApiBase$path'),
      headers: headers,
      body: jsonEncode(body ?? {}),
    );

    final data = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 400) {
      final message = data['message'] ?? data['error'];
      throw ApiException(
        message?.toString() ?? 'Server error ${res.statusCode}',
        statusCode: res.statusCode,
      );
    }

    return data;
  }
}
