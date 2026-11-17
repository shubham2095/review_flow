import 'session.dart';

/// What a menu entry needs, with the same keys the web app uses in
/// `frontend/lib/nav.ts`: a permission (what the person may do) and/or a plan
/// feature (what the plan includes). Leave a field out when it is not needed.
class NavRule {
  const NavRule({this.perm, this.feature});

  final String? perm;
  final String? feature;
}

/// Whether [user] may see an entry that needs [rule]. This only decides what to
/// show: the server still checks every call.
///
/// Same rules as the web sidebar:
/// - a super admin sees everything;
/// - a permission is required only when the server sent the person's list
///   (a missing list hides nothing, so an older server never empties the menu);
/// - a plan feature is required only when the plan has a feature list
///   (no list means no feature gating).
bool navAllowed(AppUser? user, NavRule rule) {
  if (user == null) return false;
  if (user.isSuperAdmin) return true;
  final perm = rule.perm;
  final perms = user.permissions;
  if (perm != null && perms != null && !perms.contains(perm)) return false;
  final feature = rule.feature;
  final features = user.planFeatures;
  if (feature != null && features != null && !features.contains(feature)) {
    return false;
  }
  return true;
}

/// True when [rules] is empty (everyone) or [user] passes at least one rule.
bool navAllowedAny(AppUser? user, List<NavRule> rules) =>
    rules.isEmpty || rules.any((r) => navAllowed(user, r));

/// The rules for entries that are not WhatsApp places, so every key lives in
/// one file.
class NavRules {
  NavRules._();

  /// "Plans & billing" in the account section.
  static const billing = NavRule(perm: 'billing.view');
}
