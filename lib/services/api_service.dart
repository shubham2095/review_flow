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

  Future<Map<String, dynamic>> get(String path) async {
    final token = await _requireToken();
    final res = await http.get(
      Uri.parse('$kApiBase$path'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _decode(res);
  }

  Future<List<dynamic>> getList(String path) async {
    final token = await _requireToken();
    final res = await http.get(
      Uri.parse('$kApiBase$path'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode >= 400) _decode(res);
    return jsonDecode(res.body) as List<dynamic>;
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
      headers['Authorization'] = 'Bearer ${await _requireToken()}';
    }

    final res = await http.post(
      Uri.parse('$kApiBase$path'),
      headers: headers,
      body: jsonEncode(body ?? {}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _requireToken();
    final req = http.Request(method, Uri.parse('$kApiBase$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await req.send());
    return _decode(res);
  }

  Future<String> _requireToken() async {
    final token = await readToken();
    if (token == null) {
      throw ApiException('Login nahi hai', statusCode: 401);
    }
    return token;
  }

  Map<String, dynamic> _decode(http.Response res) {
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
