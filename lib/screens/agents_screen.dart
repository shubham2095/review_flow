import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/agents_models.dart';
import '../services/access_problem.dart';
import '../services/agents_service.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';
import 'whatsapp_chat_screen.dart';
import 'whatsapp_inbox_screen.dart' show shortWhen;

/// "Active chats" and "handled" in one plain line.
String agentWorkloadLine(WaAgent a) =>
    '${a.activeChats} active ${a.activeChats == 1 ? 'chat' : 'chats'} · '
    '${a.totalHandled} handled';

/// The state of a chat as a word and a colour.
(String, Color) agentChatStatus(String status) => switch (status) {
  'open' => ('Open', brand),
  'pending' => ('Pending', warn),
  'resolved' => ('Resolved', good),
  'closed' => ('Closed', muted),
  _ => (
    status.isEmpty ? '—' : status[0].toUpperCase() + status.substring(1),
    muted,
  ),
};

Widget _failure(
  Object error, {
  required String title,
  required VoidCallback onRetry,
}) {
  final access = accessProblem(error);
  if (access != null) {
    return StateView(icon: access.icon, title: access.title, text: access.text);
  }
  return StateView.error(
    title: title,
    text: friendlyException(error).message,
    onRetry: onRetry,
  );
}

/// The people in the business, with how many chats each one has. Tap a person
/// for their chats.
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<WaAgent> _agents = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final agents = await AgentsService.roster();
      if (!mounted) return;
      setState(() {
        _agents = agents;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _open(WaAgent a) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AgentDetailScreen(agent: a)),
    );
    if (mounted) _load();
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 5, itemHeight: 82, headerHeight: null);
    }
    final error = _error;
    if (error != null && _agents.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: _failure(
            error,
            title: 'Could not load agents',
            onRetry: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ),
      );
    }
    if (_agents.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          StateView(
            icon: Icons.headset_mic_outlined,
            title: 'No agents yet',
            text: 'People you add to your team appear here with their chats.',
          ),
        ],
      );
    }
    final active = _agents.fold<int>(0, (s, a) => s + a.activeChats);
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ContentWidth(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _agents.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  '${_agents.length} ${_agents.length == 1 ? 'person' : 'people'}'
                  ' · $active active ${active == 1 ? 'chat' : 'chats'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              );
            }
            return _AgentRow(agent: _agents[i - 1], onTap: _open);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Agents',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent, required this.onTap});

  final WaAgent agent;
  final ValueChanged<WaAgent> onTap;

  @override
  Widget build(BuildContext context) {
    final a = agent;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${a.name}${a.roleLabel.isEmpty ? '' : ', ${a.roleLabel}'}, '
          '${agentWorkloadLine(a)}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: cardDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onTap(a),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ContactAvatar(name: a.name, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                            ),
                            if (a.roleLabel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              InfoChip(a.roleLabel),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          agentWorkloadLine(a),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One agent: their numbers and their latest chats. Tap a chat to open it.
class AgentDetailScreen extends StatefulWidget {
  const AgentDetailScreen({super.key, required this.agent});

  /// What the roster already knows, shown while the chats load.
  final WaAgent agent;

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  WaAgentDetail? _detail;
  WaAgentStat? _stat;
  bool _loading = true;
  bool _opening = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await AgentsService.detail(widget.agent.id);
      // The breakdown is a bonus: a failure here must not hide the chats.
      WaAgentStat? stat;
      try {
        stat = (await AgentsService.stats())[widget.agent.id];
      } catch (_) {
        stat = null;
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _stat = stat;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openChat(WaAgentChat c) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final conversation = await WhatsAppService.findConversation(c.id);
      if (!mounted) return;
      if (conversation == null) {
        showToast(context, 'Could not open this chat.');
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => WhatsAppChatScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _summary(WaAgent a) {
    final s = _stat;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ContactAvatar(name: a.name, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: ink,
                      ),
                    ),
                    if (a.email.isNotEmpty)
                      Text(
                        a.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: muted,
                        ),
                      ),
                    if (a.roleLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InfoChip(a.roleLabel),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Mini('${a.activeChats}', 'active'),
              _Mini('${a.totalHandled}', 'handled'),
              if (s != null) ...[
                _Mini('${s.open}', 'open'),
                _Mini('${s.pending}', 'pending'),
                _Mini('${s.resolved}', 'resolved'),
                _Mini('${s.closed}', 'closed'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chatRow(WaAgentChat c) {
    final (label, color) = agentChatStatus(c.status);
    final when = shortWhen(c.lastMessageAt);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: [c.title, label, if (when.isNotEmpty) when].join(', '),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: cardDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _opening ? null : () => _openChat(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  ContactAvatar(name: c.title, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        if (when.isNotEmpty)
                          Text(
                            when,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(label, color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 82, headerHeight: 150);
    }
    final error = _error;
    final d = _detail;
    if (error != null && d == null) {
      return Center(
        child: SingleChildScrollView(
          child: _failure(
            error,
            title: 'Could not load this agent',
            onRetry: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ),
      );
    }
    final agent = d!.agent;
    final chats = d.chats;
    final lead = chats.isEmpty ? 3 : 2;
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ContentWidth(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: lead + chats.length,
          itemBuilder: (_, i) {
            if (i == 0) return _summary(agent);
            if (i == 1) {
              return SectionTitle(
                'Latest chats',
                padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
                trailing: chats.length >= 50
                    ? const InfoChip('Latest 50')
                    : null,
              );
            }
            if (chats.isEmpty && i == 2) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No chats are assigned to ${agent.name} right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: muted),
                ),
              );
            }
            return _chatRow(chats[i - lead]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          widget.agent.name,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: ink,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}
