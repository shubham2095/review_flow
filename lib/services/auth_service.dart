import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';
import 'session.dart';

class AuthService {
  /// Saves the JWT from an auth response and stores the returned user.
  static Future<void> _store(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Sign-in failed. Please try again.');
    }
    await ApiService.instance.saveToken(token);
    final user = data['user'];
    if (user is Map<String, dynamic>) Session.setFromPayload(user);
  }

  static Future<void> loginWithEmail(String email, String password) async {
    final data = await ApiService.instance.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    await _store(data);
  }

  static Future<void> loginWithGoogle(String idToken) async {
    final data = await ApiService.instance.post(
      '/auth/google',
      body: {'id_token': idToken},
      auth: false,
    );
    await _store(data);
  }

  static Future<void> register({
    required String companyName,
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await ApiService.instance.post(
      '/auth/register',
      body: {
        'company_name': companyName,
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      },
      auth: false,
    );
    await _store(data);
  }

  static Future<void> requestOtp(String phone) async {
    await ApiService.instance.post(
      '/auth/otp/request',
      body: {'phone': phone},
      auth: false,
    );
  }

  static Future<void> verifyOtp(String phone, String code) async {
    final data = await ApiService.instance.post(
      '/auth/otp/verify',
      body: {'phone': phone, 'code': code},
      auth: false,
    );
    await _store(data);
  }

  static Future<String> googleIdToken() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw ApiException('Could not get Google ID token');
    }
    return idToken;
  }

  /// One-time link that opens the web app already signed in (payments happen there).
  static Future<String> webSessionUrl() async {
    final data = await ApiService.instance.post('/auth/web-session');
    return data['login_url'] as String;
  }

  static Future<void> logout() async {
    try {
      await ApiService.instance.post('/auth/logout');
    } catch (_) {
      // Token pehle se expire ho chuka ho sakta hai; local token clear karna hi kaafi hai.
    }
    await ApiService.instance.clearToken();
    Session.clear();
  }
}
