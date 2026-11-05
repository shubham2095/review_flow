import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';
import 'session.dart';

/// The person closed the Google account chooser. Not an error.
class SignInCancelled implements Exception {}

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

  /// Shows the Google account chooser and returns a fresh ID token for the
  /// backend. Throws [SignInCancelled] when the person backs out (not an error
  /// to show) and a friendly [ApiException] for real failures.
  static Future<String> googleIdToken() async {
    try {
      // Forget the cached account so the chooser always appears and people can
      // switch to another Google account.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException('Google did not return a sign-in token. Please try again.');
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          throw SignInCancelled();
        case GoogleSignInExceptionCode.interrupted:
          throw ApiException('Google sign-in was interrupted. Please try again.');
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw ApiException(
            'Google sign-in is not set up correctly on this build. Please update the app or contact support.',
          );
        case GoogleSignInExceptionCode.uiUnavailable:
          throw ApiException('Google sign-in could not open. Please try again.');
        default:
          throw ApiException('Google sign-in failed. Please try again.');
      }
    }
  }

  /// One-time link that opens the web app already signed in (payments happen there).
  /// [next] (/billing, /plans or /buy-credits) must go in the request body: the
  /// server stores it with the one-time code and ignores it on the link itself.
  static Future<String> webSessionUrl({String? next}) async {
    final data = await ApiService.instance.post(
      '/auth/web-session',
      body: {'next': ?next},
    );
    return data['login_url'] as String;
  }

  /// Permanently deletes the account. Email users confirm with their password,
  /// Google users with a fresh Google ID token. Clears the local session after.
  static Future<void> deleteAccount({String? password, String? idToken}) async {
    await ApiService.instance.delete(
      '/auth/account',
      body: {'password': ?password, 'id_token': ?idToken},
    );
    await ApiService.instance.clearToken();
    Session.clear();
  }

  static Future<void> logout() async {
    try {
      await ApiService.instance.post('/auth/logout');
    } catch (_) {
      // Token pehle se expire ho chuka ho sakta hai; local token clear karna hi kaafi hai.
    }
    await ApiService.instance.clearToken();
    Session.clear();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
