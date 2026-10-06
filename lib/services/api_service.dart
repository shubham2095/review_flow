import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kAppUrl = 'https://review.heltog.com';
const String kApiBase = '$kAppUrl/api';

const _networkMessage = 'No internet connection. Check your network and try again.';
const _serverMessage = 'Something went wrong on our side. Please try again in a moment.';
const _timeoutMessage = 'The server is taking too long. Please try again.';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Turns any low-level failure into a message that is safe to show to the user.
/// Raw server or database errors never reach the screen.
ApiException friendlyException(Object e) {
  if (e is ApiException) return e;
  if (e is TimeoutException) return ApiException(_timeoutMessage);
  if (e is SocketException || e is http.ClientException) return ApiException(_networkMessage);
  if (e is FormatException) return ApiException(_serverMessage);
  return ApiException(_serverMessage);
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const _tokenKey = 'sanctum_token';
  static const _timeout = Duration(seconds: 30);

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
    final res = await _run(() async {
      final token = await _requireToken();
      return http.get(Uri.parse('$kApiBase$path'), headers: _headers(token));
    });
    return _decode(res);
  }

  Future<List<int>> getBytes(String path) async {
    final res = await _run(() async {
      final token = await _requireToken();
      return http.get(Uri.parse('$kApiBase$path'), headers: {'Authorization': 'Bearer $token'});
    });
    if (res.statusCode >= 400) _decode(res);
    return res.bodyBytes;
  }

  Future<List<dynamic>> getList(String path) async {
    final res = await _run(() async {
      final token = await _requireToken();
      return http.get(Uri.parse('$kApiBase$path'), headers: _headers(token));
    });
    if (res.statusCode >= 400) _decode(res);
    return _parseJsonList(_text(res));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final res = await _run(() async {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      if (auth) {
        headers['Authorization'] = 'Bearer ${await _requireToken()}';
      }
      return http.post(
        Uri.parse('$kApiBase$path'),
        headers: headers,
        body: jsonEncode(body ?? {}),
      );
    });
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
    final res = await _run(() async {
      final token = await _requireToken();
      final req = http.Request(method, Uri.parse('$kApiBase$path'))
        ..headers.addAll({..._headers(token), 'Content-Type': 'application/json'});
      if (body != null) req.body = jsonEncode(body);
      return http.Response.fromStream(await req.send());
    });
    return _decode(res);
  }

  Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Runs one request. Network, timeout and unexpected failures become friendly ApiExceptions.
  Future<http.Response> _run(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw friendlyException(e);
    }
  }

  Future<String> _requireToken() async {
    final token = await readToken();
    if (token == null) {
      throw ApiException('Please log in again.', statusCode: 401);
    }
    return token;
  }

  List<dynamic> _parseJsonList(String body) {
    try {
      return jsonDecode(body) as List<dynamic>;
    } catch (_) {
      throw ApiException(_serverMessage);
    }
  }

  /// Server JSON hamesha UTF-8 hota hai. http package bina charset ke Latin-1 maan leta hai, isliye ye zaroori hai.
  String _text(http.Response res) => utf8.decode(res.bodyBytes, allowMalformed: true);

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data;
    try {
      data = _text(res).isEmpty ? <String, dynamic>{} : jsonDecode(_text(res)) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (res.statusCode >= 400) {
      throw ApiException(_userMessage(res.statusCode, data), statusCode: res.statusCode);
    }

    return data;
  }

  /// Server ka message tabhi dikhate hain jo user ke liye safe ho.
  /// 5xx ya technical text (SQL, stack trace) ho to generic message dikhate hain.
  String _userMessage(int status, Map<String, dynamic> data) {
    if (status >= 500) return _serverMessage;
    if (status == 401) return 'Your session has ended. Please log in again.';
    if (status == 403) return 'You do not have permission to do this.';
    if (status == 404) return 'Not found.';
    if (status == 429) return 'Too many requests. Please wait a moment.';

    final raw = (data['message'] ?? data['error'])?.toString();
    if (raw == null || raw.isEmpty) return 'Request failed. Please try again.';
    if (_looksTechnical(raw)) return _serverMessage;
    return raw;
  }

  bool _looksTechnical(String text) {
    final lower = text.toLowerCase();
    return text.length > 200 ||
        lower.contains('sqlstate') ||
        lower.contains('stack trace') ||
        lower.contains('exception') ||
        lower.contains('connection:') ||
        lower.contains('syntax error');
  }
}
