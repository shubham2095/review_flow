int _i(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toInt() ?? 0;

String _s(dynamic v) => v?.toString() ?? '';

class TeamMember {
  TeamMember.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']),
        email = _s(j['email']),
        role = _s(j['role']).isEmpty ? 'STAFF' : _s(j['role']);

  final int id;
  final String name;
  final String email;
  final String role;
}

const roleLabels = {
  'STAFF': 'Staff',
  'MARKETING_MANAGER': 'Marketing manager',
};
