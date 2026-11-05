import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'location_store.dart';

/// The signed-in user as returned by GET /auth/me.
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.address,
    this.isSuperAdmin = false,
    this.emailVerified = false,
    this.businessName,
    this.planName,
    this.subscriptionStatus,
    this.planFeatures,
    this.periodEnd,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final sub = j['subscription'];
    final tenant = j['tenant'];
    final features = j['plan_features'];
    return AppUser(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      phone: j['phone']?.toString(),
      avatarUrl: j['avatar_url']?.toString(),
      address: j['address']?.toString(),
      isSuperAdmin: j['is_super_admin'] == true,
      emailVerified: j['email_verified'] == true,
      businessName: tenant is Map
          ? (tenant['company_name'] ?? tenant['name'])?.toString()
          : null,
      planName: sub is Map ? sub['plan_name']?.toString() : null,
      subscriptionStatus: sub is Map ? sub['status']?.toString() : null,
      periodEnd: sub is Map ? sub['current_period_end']?.toString() : null,
      planFeatures: features is List
          ? features.map((e) => e.toString()).toList()
          : null,
    );
  }

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? address;
  final bool isSuperAdmin;
  final bool emailVerified;
  final String? businessName;
  final String? planName;
  final String? subscriptionStatus;
  final List<String>? planFeatures;
  final String? periodEnd;

  /// Mirrors the backend rule: only an active or trialing subscription unlocks
  /// the workspace. Super admins are never gated.
  bool get hasPlan =>
      isSuperAdmin ||
      subscriptionStatus == 'active' ||
      subscriptionStatus == 'trialing';

  /// Null feature list means "no gating" (super admin) or "no plan".
  bool hasFeature(String key) =>
      isSuperAdmin || (planFeatures?.contains(key) ?? false);
}

/// Holds the current user for the whole app.
class Session {
  Session._();

  static final ValueNotifier<AppUser?> user = ValueNotifier<AppUser?>(null);

  static AppUser? get current => user.value;

  static void setFromPayload(Map<String, dynamic> userJson) {
    user.value = AppUser.fromJson(userJson);
  }

  static void clear() {
    user.value = null;
    LocationStore.clear();
  }

  /// Reloads the user (and plan state) from the server.
  static Future<AppUser> refresh() async {
    final data = await ApiService.instance.get('/auth/me');
    final u = data['user'];
    if (u is! Map<String, dynamic>) {
      throw ApiException('Could not load your account. Please try again.');
    }
    final parsed = AppUser.fromJson(u);
    user.value = parsed;
    return parsed;
  }
}
