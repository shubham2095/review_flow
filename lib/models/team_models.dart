import 'gbp_models.dart' show asDate, asMap, asMaps, asStr;

/// One thing an agent can be given (Inbox, Contacts...): GET /team `features`.
class TeamFeature {
  const TeamFeature({required this.key, required this.label});

  factory TeamFeature.fromJson(Map<String, dynamic> j) =>
      TeamFeature(key: asStr(j['key']), label: asStr(j['label']));

  final String key;
  final String label;
}

/// A person in the business: GET /team `members`.
class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.status = 'active',
    this.role = 'agent',
    this.roleLabel = 'Agent',
    this.features = const [],
    this.lastLoginAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) {
    final role = asStr(j['role']).isEmpty ? 'agent' : asStr(j['role']);
    final label = asStr(j['role_label']);
    return TeamMember(
      id: asStr(j['id']),
      name: asStr(j['name']),
      email: asStr(j['email']),
      avatarUrl: asStr(j['avatar_url']),
      status: asStr(j['status']).isEmpty ? 'active' : asStr(j['status']),
      role: role,
      roleLabel: label.isEmpty ? (role == 'admin' ? 'Admin' : 'Agent') : label,
      features: j['features'] is List
          ? (j['features'] as List).map((e) => e.toString()).toList()
          : const [],
      lastLoginAt: asDate(j['last_login_at']),
    );
  }

  final String id;
  final String name;
  final String email;
  final String avatarUrl;

  /// `active` or `suspended`.
  final String status;

  /// `admin` (full access) or `agent` (only the ticked features).
  final String role;
  final String roleLabel;
  final List<String> features;
  final DateTime? lastLoginAt;

  bool get isActive => status == 'active';
  bool get isAdmin => role == 'admin';
}

/// GET /team: the members and the features that can be ticked for an agent.
class TeamData {
  const TeamData({required this.members, required this.features});

  factory TeamData.fromJson(Map<String, dynamic> j) => TeamData(
    members: asMaps(j['members']).map(TeamMember.fromJson).toList(),
    features: asMaps(j['features']).map(TeamFeature.fromJson).toList(),
  );

  final List<TeamMember> members;
  final List<TeamFeature> features;
}

/// The member the server returns after create, update and toggle.
TeamMember teamMemberFrom(Map<String, dynamic> res) =>
    TeamMember.fromJson(asMap(res['member']));
