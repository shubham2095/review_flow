import 'gbp_models.dart' show asDate, asInt, asMap, asMaps, asStr;

/// One person who can be given chats: GET /agents (the roster).
class WaAgent {
  const WaAgent({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.roles = const [],
    this.activeChats = 0,
    this.totalHandled = 0,
  });

  factory WaAgent.fromJson(Map<String, dynamic> j) => WaAgent(
    id: asStr(j['id']),
    name: asStr(j['name']),
    email: asStr(j['email']),
    avatarUrl: asStr(j['avatar_url']),
    roles: j['roles'] is List
        ? (j['roles'] as List).map((e) => e.toString()).toList()
        : const [],
    activeChats: asInt(j['active_conversations_count']),
    totalHandled: asInt(j['total_handled']),
  );

  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final List<String> roles;

  /// Chats that are open or pending and assigned to this person.
  final int activeChats;

  /// Distinct chats that were ever assigned to this person.
  final int totalHandled;

  /// "Owner", "Admin", "Agent" for the first role, or empty.
  String get roleLabel {
    if (roles.isEmpty) return '';
    final r = roles.first;
    return r.isEmpty ? '' : r[0].toUpperCase() + r.substring(1);
  }
}

/// A chat assigned to an agent (GET /agents/{id}).
class WaAgentChat {
  const WaAgentChat({
    required this.id,
    required this.contactName,
    required this.contactPhone,
    required this.status,
    this.lastMessageAt,
  });

  factory WaAgentChat.fromJson(Map<String, dynamic> j) => WaAgentChat(
    id: asStr(j['id']),
    contactName: asStr(j['contact_name']),
    contactPhone: asStr(j['contact_phone']),
    status: asStr(j['status']),
    lastMessageAt: asDate(j['last_message_at']),
  );

  final String id;
  final String contactName;
  final String contactPhone;
  final String status;
  final DateTime? lastMessageAt;

  /// The name, or the number when the contact has no name.
  String get title => contactName.isNotEmpty ? contactName : contactPhone;
}

/// GET /agents/{id}: the agent and up to 50 of their latest chats.
class WaAgentDetail {
  const WaAgentDetail({required this.agent, required this.chats});

  factory WaAgentDetail.fromJson(Map<String, dynamic> j) {
    final a = asMap(j['agent']);
    return WaAgentDetail(
      agent: WaAgent.fromJson(a),
      chats: asMaps(a['conversations']).map(WaAgentChat.fromJson).toList(),
    );
  }

  final WaAgent agent;
  final List<WaAgentChat> chats;
}

/// GET /agents/stats: how many chats an agent has in each state.
class WaAgentStat {
  const WaAgentStat({
    required this.id,
    this.open = 0,
    this.pending = 0,
    this.resolved = 0,
    this.closed = 0,
    this.total = 0,
  });

  factory WaAgentStat.fromJson(Map<String, dynamic> j) => WaAgentStat(
    id: asStr(j['id']),
    open: asInt(j['open']),
    pending: asInt(j['pending']),
    resolved: asInt(j['resolved']),
    closed: asInt(j['closed']),
    total: asInt(j['total']),
  );

  final String id;
  final int open;
  final int pending;
  final int resolved;
  final int closed;
  final int total;
}

/// GET /agents/assignable: id and name for the "give this chat to" picker.
class WaAssignable {
  const WaAssignable({required this.id, required this.name, this.isMe = false});

  factory WaAssignable.fromJson(Map<String, dynamic> j) => WaAssignable(
    id: asStr(j['id']),
    name: asStr(j['name']),
    isMe: j['is_me'] == true,
  );

  final String id;
  final String name;
  final bool isMe;
}

/// What the assign sheet returns: the new assignee ("" when unassigned) and
/// the server's sentence for a toast.
class AssignResult {
  const AssignResult({required this.agentName, required this.message});

  final String agentName;
  final String message;
}
