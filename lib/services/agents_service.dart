import '../models/agents_models.dart';
import '../models/gbp_models.dart' show asMaps, asStr;
import 'api_service.dart';

/// Agents and chat assignment (/api/v1/agents/...).
class AgentsService {
  AgentsService._();

  static final _api = ApiService.instance;

  static String _msg(Map<String, dynamic> res, String fallback) {
    final m = asStr(res['message']);
    return m.isEmpty ? fallback : m;
  }

  /// Everyone in the business with their chat workload.
  static Future<List<WaAgent>> roster() async {
    final res = await _api.get('/agents');
    return asMaps(res['agents']).map(WaAgent.fromJson).toList();
  }

  static Future<WaAgentDetail> detail(String id) async =>
      WaAgentDetail.fromJson(await _api.get('/agents/$id'));

  /// Chats per state for the agents that have any, by agent id.
  static Future<Map<String, WaAgentStat>> stats() async {
    final res = await _api.get('/agents/stats');
    return {
      for (final s in asMaps(res['stats']).map(WaAgentStat.fromJson)) s.id: s,
    };
  }

  /// Active people a chat can be given to (any inbox user may read this).
  static Future<List<WaAssignable>> assignable() async {
    final res = await _api.get('/agents/assignable');
    return asMaps(res['agents']).map(WaAssignable.fromJson).toList();
  }

  static Future<String> assign(String conversationId, String agentId) async =>
      _msg(
        await _api.post(
          '/agents/assign',
          body: {'conversation_id': conversationId, 'agent_id': agentId},
        ),
        'Chat assigned.',
      );

  static Future<String> unassign(String conversationId) async => _msg(
    await _api.post(
      '/agents/unassign',
      body: {'conversation_id': conversationId},
    ),
    'Chat unassigned.',
  );
}
