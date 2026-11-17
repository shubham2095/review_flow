import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/team_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../services/team_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';
import 'team_member_sheet.dart';

/// What a person can use, as a few chip labels and how many more there are.
/// An Admin has everything; an agent has what was ticked.
(List<String>, int) teamFeatureSummary(
  TeamMember m,
  List<TeamFeature> catalog, {
  int max = 3,
}) {
  if (m.isAdmin) return (const ['Full access'], 0);
  final labels = [
    for (final f in catalog)
      if (m.features.contains(f.key)) f.label,
  ];
  if (labels.isEmpty) return (const ['Nothing ticked yet'], 0);
  if (labels.length <= max) return (labels, 0);
  return (labels.sublist(0, max), labels.length - max);
}

/// Your team: who can sign in, what they can use, and a way to add, edit,
/// suspend or remove them. A page of the home shell (no app bar of its own).
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  TeamData? _data;
  bool _loading = true;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await TeamService.list();
      if (!mounted) return;
      setState(() {
        _data = d;
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

  Future<void> _sheet({TeamMember? member}) async {
    final d = _data;
    if (d == null) return;
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => TeamMemberSheet(features: d.features, member: member),
    );
    if (message == null || !mounted) return;
    showToast(context, message);
    _load();
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
    bool danger = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: bad) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      showToast(context, message);
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(TeamMember m) async {
    if (m.isActive &&
        !await _confirm(
          title: 'Suspend ${m.name}?',
          text:
              'They can no longer sign in until you turn them on again. '
              'Their chats and work stay as they are.',
          action: 'Suspend',
        )) {
      return;
    }
    await _run(() async {
      final fresh = await TeamService.toggle(m.id);
      return fresh.isActive
          ? '${m.name} can sign in again.'
          : '${m.name} is suspended.';
    });
  }

  Future<void> _remove(TeamMember m) async {
    if (!await _confirm(
      title: 'Remove ${m.name}?',
      text:
          'They lose access and cannot sign in. This cannot be undone from '
          'the app.',
      action: 'Remove',
      danger: true,
    )) {
      return;
    }
    await _run(() => TeamService.remove(m.id));
  }

  Widget _memberCard(TeamMember m, List<TeamFeature> catalog, bool isMe) {
    final (shown, more) = teamFeatureSummary(m, catalog);
    final login = m.lastLoginAt == null
        ? 'Has not signed in yet'
        : 'Last sign-in ${fmtDate(m.lastLoginAt!)}';
    return Semantics(
      container: true,
      label:
          '${m.name}${isMe ? ' (you)' : ''}, ${m.roleLabel}, '
          '${m.isActive ? 'active' : 'suspended'}, ${shown.join(', ')}'
          '${more > 0 ? ' and $more more' : ''}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: cardDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _busy ? null : () => _sheet(member: m),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContactAvatar(name: m.name, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                isMe ? '${m.name} (you)' : m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InfoChip(m.roleLabel),
                          ],
                        ),
                        Text(
                          m.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusBadge(
                              m.isActive ? 'Active' : 'Suspended',
                              m.isActive ? good : warn,
                            ),
                            for (final label in shown)
                              InfoChip(label, color: brand),
                            if (more > 0) InfoChip('+$more more'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          login,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More for ${m.name}',
                    enabled: !_busy,
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          _sheet(member: m);
                        case 'toggle':
                          _toggle(m);
                        case 'remove':
                          _remove(m);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      // The server refuses these for your own account.
                      if (!isMe)
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(m.isActive ? 'Suspend' : 'Turn on again'),
                        ),
                      if (!isMe)
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove'),
                        ),
                    ],
                  ),
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
      return const SkeletonList(count: 4, itemHeight: 82, headerHeight: 56);
    }
    final error = _error;
    final d = _data;
    if (error != null && d == null) {
      final access = accessProblem(error);
      return Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load your team',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    final data = d!;
    final me = Session.current?.id;
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ContentWidth(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: data.members.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${data.members.length} '
                        '${data.members.length == 1 ? 'person' : 'people'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _sheet(),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: const Text('Add agent'),
                    ),
                  ],
                ),
              );
            }
            final m = data.members[i - 1];
            return _memberCard(m, data.features, m.id == me);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
