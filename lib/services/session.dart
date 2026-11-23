import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'location_store.dart';
import 'offline_cache.dart';
import 'profile_rules.dart';

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
    this.permissions,
    this.roles = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final sub = j['subscription'];
    final tenant = j['tenant'];
    final features = j['plan_features'];
    final perms = j['permissions'];
    final roles = j['roles'];
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
      permissions: perms is List
          ? perms.map((e) => e.toString()).toList()
          : null,
      roles: roles is List ? roles.map((e) => e.toString()).toList() : const [],
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

  /// What this person may do inside their business, as the server lists it
  /// (for example `conversations.view`). Null when the server did not send the
  /// list: the app then hides nothing and the server decides.
  final List<String>? permissions;

  /// Role names such as `owner`, `admin` or `agent`.
  final List<String> roles;

  /// An account made by signing up with a mobile number starts with stand-in
  /// details (see profile_rules.dart). These say which ones are still stand-ins.
  bool get hasStandInEmail => isStandInEmail(email);
  bool get hasStandInName => isStandInName(name);
  bool get hasStandInBusiness => isStandInBusiness(businessName);

  /// The name to greet and label the person with: empty while it is a
  /// stand-in, so screens fall back to their no-name wording.
  String get displayName => hasStandInName ? '' : name;

  /// Parts of the profile still to fill in, in plain words.
  List<String> get missingProfileParts => [
    if (hasStandInName) 'your name',
    if (businessName != null && hasStandInBusiness) 'your business name',
    if (hasStandInEmail) 'your email',
  ];

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
    // Saved offline copies belong to the person who just left.
    OfflineCache.clear();
    ApiService.servingSavedData.value = null;
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
