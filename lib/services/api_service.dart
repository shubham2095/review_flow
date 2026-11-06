import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'offline_cache.dart';

const String kAppUrl = 'https://eydia.in';

/// Override per build: flutter run --dart-define=API_BASE=https://staging.example.com/api/v1
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: '$kAppUrl/api/v1',
);

/// AI-backed endpoints (Gemini calls, bulk optimize, image generation) can
/// legitimately take longer than a normal API call. Pass this to [ApiService.post]
/// for those so a slow-but-working server isn't mistaken for a timeout.
const kAiTimeout = Duration(seconds: 90);

/// Shown when the phone has no connection. Screens compare against it to show
/// the "you are offline" look instead of a generic failure.
const kNetworkMessage =
    'No internet connection. Check your network and try again.';
const _serverMessage =
    'Something went wrong on our side. Please try again in a moment.';
const _timeoutMessage = 'The server is taking too long. Please try again.';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.errors});

  final String message;
  final int? statusCode;

  /// Stable machine-readable reason from the backend (plan_required, ...), or
  /// `offline` / `timeout` for failures that never reached the server.
  final String? code;
  final Map<String, dynamic>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isPlanRequired => code == 'plan_required';
  bool get isFeatureLocked => code == 'feature_not_included';
  bool get isCreditsInsufficient => code == 'credits_insufficient';
  bool get isOffline => code == 'offline';

  /// The server could not be reached or is down: saved data is a fair stand-in.
  bool get isUnreachable =>
      code == 'offline' || code == 'timeout' || (statusCode ?? 0) >= 500;

  @override
  String toString() => message;
}

/// Turns any low-level failure into a message that is safe to show to the user.
/// Raw server or database errors never reach the screen.
ApiException friendlyException(Object e) {
  if (e is ApiException) return e;
  if (e is TimeoutException) {
    return ApiException(_timeoutMessage, code: 'timeout');
  }
  if (e is SocketException || e is http.ClientException) {
    return ApiException(kNetworkMessage, code: 'offline');
  }
  return ApiException(_serverMessage);
}

/// Thin client for the Eydia Laravel API (/api/v1).
///
/// Every response is `{success, data}` or `{success:false, message, errors, code?}`.
/// The get/post/put/delete helpers return the unwrapped `data` as a Map (a list
/// payload comes back as `{'items': [...]}`); [getList] returns a list payload.
/// Auth is a JWT. An expired token is refreshed once through /auth/refresh and
/// the request is retried; if that fails [sessionExpired] ticks and the token
/// is cleared so the app returns to the login screen.
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  /// Ticks whenever the session can no longer be recovered.
  static final ValueNotifier<int> sessionExpired = ValueNotifier<int>(0);

  /// Ticks when any call is refused with code plan_required (plan ended).
  static final ValueNotifier<int> planRequired = ValueNotifier<int>(0);

  static const _tokenKey = 'eydia_jwt';
  static const _timeout = Duration(seconds: 30);
  static const _storage = FlutterSecureStorage();

  Future<bool>? _refreshing;

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  /// Set while a screen is showing data saved earlier because the server could
  /// not be reached; holds when that data was saved. Null when everything is live.
  static final ValueNotifier<DateTime?> servingSavedData =
      ValueNotifier<DateTime?>(null);

  /// Ticks when the connection comes back after saved data was shown.
  static final ValueNotifier<int> reconnected = ValueNotifier<int>(0);

  void _markOnline() {
    if (servingSavedData.value == null) return;
    servingSavedData.value = null;
    reconnected.value++;
  }

  /// True when the server answers. Used to notice that the connection is back.
  Future<bool> checkReachable() async {
    try {
      await getPublic('/app/config', timeout: const Duration(seconds: 5));
      _markOnline();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GET that remembers what it fetched. If the server cannot be reached later,
  /// the last saved copy is returned instead of an error (and
  /// [servingSavedData] tells the UI), so the app stays useful offline.
  Future<dynamic> _getPayload(String path) async {
    try {
      final res = await _authed(
        (token) => http.get(_uri(path), headers: _headers(token)),
      );
      final payload = _unwrap(res);
      _markOnline();
      OfflineCache.write(path, payload);
      return payload;
    } on ApiException catch (e) {
      if (e.isUnreachable) {
        final saved = await OfflineCache.read(path);
        if (saved != null) {
          servingSavedData.value = saved.savedAt;
          return saved.data;
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> get(String path) async =>
      _asMap(await _getPayload(path));

  Future<List<int>> getBytes(String path) async {
    final res = await _authed(
      (token) => http.get(_uri(path), headers: _headers(token)),
    );
    if (res.statusCode >= 400) _unwrap(res);
    return res.bodyBytes;
  }

  Future<List<dynamic>> getList(String path) async {
    final payload = await _getPayload(path);
    return payload is List ? payload : <dynamic>[];
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    Duration? timeout,
  }) async {
    final encoded = jsonEncode(body ?? {});
    final http.Response res;
    if (auth) {
      res = await _authed(
        (token) => http.post(
          _uri(path),
          headers: {..._headers(token), 'Content-Type': 'application/json'},
          body: encoded,
        ),
        timeout: timeout,
      );
    } else {
      res = await _run(
        () => http.post(
          _uri(path),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: encoded,
        ),
        timeout: timeout,
      );
    }
    return _asMap(_unwrap(res));
  }

  /// Multipart upload of one file (field name as the endpoint expects, e.g. `file`).
  Future<Map<String, dynamic>> upload(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) async {
    final res = await _authed((token) async {
      final req = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers(token))
        ..files.add(
          http.MultipartFile.fromBytes(field, bytes, filename: filename),
        );
      return http.Response.fromStream(await req.send());
    }, timeout: const Duration(seconds: 120));
    return _asMap(_unwrap(res));
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) => _send('DELETE', path, body: body);

  /// GET without a token, for public endpoints such as /app/config.
  Future<Map<String, dynamic>> getPublic(
    String path, {
    Duration? timeout,
  }) async {
    final res = await _run(
      () => http.get(_uri(path), headers: {'Accept': 'application/json'}),
      timeout: timeout,
    );
    return _asMap(_unwrap(res));
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _authed((token) async {
      final req = http.Request(method, _uri(path))
        ..headers.addAll({
          ..._headers(token),
          'Content-Type': 'application/json',
        });
      if (body != null) req.body = jsonEncode(body);
      return http.Response.fromStream(await req.send());
    });
    return _asMap(_unwrap(res));
  }

  Uri _uri(String path) => Uri.parse('$kApiBase$path');

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Authenticated request with one silent refresh-and-retry on 401.
  Future<http.Response> _authed(
    Future<http.Response> Function(String token) send, {
    Duration? timeout,
  }) async {
    var token = await _requireToken();
    var res = await _run(() => send(token), timeout: timeout);
    if (res.statusCode == 401 && await _refreshToken(token)) {
      token = await _requireToken();
      res = await _run(() => send(token), timeout: timeout);
    }
    if (res.statusCode == 401) await _endSession();
    return res;
  }

  /// One refresh at a time: parallel 401s wait for the same attempt.
  Future<bool> _refreshToken(String oldToken) {
    return _refreshing ??= _doRefresh(oldToken).whenComplete(() {
      _refreshing = null;
    });
  }

  Future<bool> _doRefresh(String oldToken) async {
    try {
      final res = await _run(
        () => http.post(
          _uri('/auth/refresh'),
          headers: {..._headers(oldToken), 'Content-Type': 'application/json'},
        ),
      );
      if (res.statusCode != 200) return false;
      final payload = _asMap(_unwrap(res));
      final fresh = payload['token']?.toString();
      if (fresh == null || fresh.isEmpty) return false;
      await saveToken(fresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _endSession() async {
    await clearToken();
    sessionExpired.value++;
  }

  /// Runs one request. Network, timeout and unexpected failures become friendly ApiExceptions.
  Future<http.Response> _run(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    try {
      return await request().timeout(timeout ?? _timeout);
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

  /// Server JSON is always UTF-8; the http package assumes Latin-1 without a charset.
  String _text(http.Response res) =>
      utf8.decode(res.bodyBytes, allowMalformed: true);

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is List) return {'items': payload};
    return <String, dynamic>{};
  }

  /// Returns the `data` payload of a successful response, or throws.
  dynamic _unwrap(http.Response res) {
    Map<String, dynamic> body;
    try {
      final text = _text(res);
      body = text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      body = <String, dynamic>{};
    }

    final failed = res.statusCode >= 400 || body['success'] == false;
    if (failed) {
      final errors = body['errors'];
      final status = res.statusCode;
      final code = _errorCode(status, body);
      if (code == 'plan_required') planRequired.value++;
      throw ApiException(
        _userMessage(status, body),
        statusCode: status,
        code: code,
        errors: errors is Map<String, dynamic> ? errors : null,
      );
    }

    return body.containsKey('data') ? body['data'] : body;
  }

  String? _errorCode(int status, Map<String, dynamic> body) {
    final explicit = body['code']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final errors = body['errors'];
    if (errors is Map) {
      final plan = errors['plan'];
      if (plan is List && plan.contains('feature_not_included')) {
        return 'feature_not_included';
      }
      final credits = errors['credits'];
      if (credits is List && credits.contains('insufficient')) {
        return 'credits_insufficient';
      }
    }
    if (status == 402) return 'credits_insufficient';
    return null;
  }

  /// Server ka message tabhi dikhate hain jo user ke liye safe ho.
  /// 5xx ya technical text (SQL, stack trace) ho to generic message dikhate hain.
  String _userMessage(int status, Map<String, dynamic> data) {
    if (status >= 500) return _serverMessage;
    if (status == 404) return 'Not found.';
    if (status == 429) return 'Too many requests. Please wait a moment.';

    final raw = (data['message'] ?? data['error'])?.toString();
    if (status == 401 &&
        (raw == null || raw.toLowerCase().startsWith('unauth'))) {
      return 'Your session has ended. Please log in again.';
    }
    if (raw == null || raw.isEmpty || _looksTechnical(raw)) {
      return status == 403
          ? 'You do not have permission to do this.'
          : 'Request failed. Please try again.';
    }
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
