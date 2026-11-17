import '../models/gbp_models.dart' show asStr;
import '../models/team_models.dart';
import 'api_service.dart';

/// The business's own people (/api/v1/team/...). Owners can only create
/// agents, so the role is always `agent`.
class TeamService {
  TeamService._();

  static final _api = ApiService.instance;

  static Future<TeamData> list() async =>
      TeamData.fromJson(await _api.get('/team'));

  static Future<TeamMember> create({
    required String name,
    required String email,
    required String password,
    required List<String> features,
  }) async => teamMemberFrom(
    await _api.post(
      '/team',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'role': 'agent',
        'features': features,
      },
    ),
  );

  /// Only what is given is sent: no password means it stays as it was, and no
  /// features means the access stays as it was (an Admin has no feature list).
  static Future<TeamMember> update(
    String id, {
    String? name,
    String? password,
    List<String>? features,
  }) async => teamMemberFrom(
    await _api.put(
      '/team/$id',
      body: {
        'name': ?name,
        if (password != null && password.isNotEmpty) 'password': password,
        'features': ?features,
      },
    ),
  );

  /// Switches the person between active and suspended.
  static Future<TeamMember> toggle(String id) async =>
      teamMemberFrom(await _api.post('/team/$id/toggle'));

  static Future<String> remove(String id) async {
    final res = await _api.delete('/team/$id');
    final m = asStr(res['message']);
    return m.isEmpty ? 'Team member removed.' : m;
  }
}
