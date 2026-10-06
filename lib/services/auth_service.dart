import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';

class AuthService {
  static Future<void> loginWithEmail(String email, String password) async {
    final data = await ApiService.instance.post(
      '/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    await ApiService.instance.saveToken(data['token'] as String);
  }

  static Future<void> loginWithGoogle(String idToken) async {
    final data = await ApiService.instance.post(
      '/auth/google',
      body: {'id_token': idToken},
      auth: false,
    );
    await ApiService.instance.saveToken(data['token'] as String);
  }

  static Future<void> register(String name, String email, String password) async {
    final data = await ApiService.instance.post(
      '/register',
      body: {'name': name, 'email': email, 'password': password},
      auth: false,
    );
    await ApiService.instance.saveToken(data['token'] as String);
  }

  static Future<String> googleIdToken() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw ApiException('Could not get Google ID token');
    }
    return idToken;
  }

  static Future<String> webSessionUrl() async {
    final data = await ApiService.instance.post('/web-session');
    return data['login_url'] as String;
  }

  static Future<void> logout() async {
    try {
      await ApiService.instance.post('/logout');
    } catch (_) {
      // Token pehle se expire ho chuka ho sakta hai; local token clear karna hi kaafi hai.
    }
    await ApiService.instance.clearToken();
  }
}
