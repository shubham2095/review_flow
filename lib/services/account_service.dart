import 'dart:convert';

import '../models/account_models.dart';
import '../models/gbp_models.dart';
import 'api_service.dart';

/// Automation, billing (read only), profile and support calls.
class AccountService {
  AccountService._();

  static final _api = ApiService.instance;

  // ---- Automation ----

  static Future<AutomationData> automation() async =>
      AutomationData.fromJson(await _api.get('/gbp/automation'));

  static Future<AutomationData> updateAutomation(
    Map<String, dynamic> body,
  ) async =>
      AutomationData.fromJson(await _api.put('/gbp/automation', body: body));

  // ---- Billing (payment itself happens on the web) ----

  static Future<SubscriptionInfo?> subscription() async {
    final res = await _api.get('/billing');
    final sub = res['subscription'];
    return sub is Map<String, dynamic> ? SubscriptionInfo.fromJson(sub) : null;
  }

  static Future<CreditsInfo> credits() async =>
      CreditsInfo.fromJson(await _api.get('/credits'));

  static Future<List<BillingInvoice>> invoices() async {
    final res = await _api.get('/billing/invoices');
    return asMaps(res['invoices']).map(BillingInvoice.fromJson).toList();
  }

  // ---- Profile ----

  static Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
    String? avatarDataUrl,
    String? email,
    String? companyName,
  }) async {
    await _api.put(
      '/auth/profile',
      body: {
        'name': ?name,
        'phone': ?phone,
        'address': ?address,
        'avatar_url': ?avatarDataUrl,
        'email': ?email,
        // Renames the workspace (the server added this for mobile sign-ups).
        'company_name': ?companyName,
      },
    );
  }

  static String avatarDataUrl(List<int> bytes, {String mime = 'image/jpeg'}) =>
      'data:$mime;base64,${base64Encode(bytes)}';

  /// [current] is optional: a mobile-number account has no password yet, and
  /// the server does not ask for the current one (the signed-in session is the
  /// proof).
  static Future<void> changePassword({
    String? current,
    required String password,
  }) async {
    await _api.post(
      '/auth/change-password',
      body: {
        'current_password': ?current,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  // ---- Support ----

  static Future<List<SupportTicket>> tickets() async {
    final res = await _api.get('/support');
    return asMaps(res['tickets']).map(SupportTicket.fromJson).toList();
  }

  static Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String category,
  }) async {
    final res = await _api.post(
      '/support',
      body: {
        'subject': subject,
        'description': description,
        'category': category,
      },
    );
    return SupportTicket.fromJson(asMap(res['ticket']));
  }
}
