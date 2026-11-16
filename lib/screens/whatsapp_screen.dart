import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';
import 'whatsapp_campaign_create_screen.dart';
import 'whatsapp_campaign_detail_screen.dart';
import 'whatsapp_chat_screen.dart';
import 'whatsapp_connect_sheet.dart';
import 'whatsapp_contact_sheet.dart';
import 'whatsapp_inbox_screen.dart'
    show InboxFilter, WhatsAppInboxScreen, shortWhen;
import 'whatsapp_number_sheet.dart';

/// WhatsApp home: how the number is doing, today's numbers, quick actions,
/// the latest chats, and a short setup guide until everything is switched on.
class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key, this.onOpenInbox});

  /// Inside the WhatsApp tabs: opening the Inbox switches to the Inbox tab
  /// (on the given filter) instead of opening a second Inbox on top. Null: it
  /// opens full-screen.
  final ValueChanged<InboxFilter>? onOpenInbox;

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  WaOverview? _data;
  List<WaConversation> _recent = [];
  bool _loading = true;
  bool _refreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The latest chats, unread first. A failure here never breaks the page: the
  /// section just does not show.
  Future<List<WaConversation>> _fetchRecent() async {
    try {
      final page = await WhatsAppService.conversations();
      final unread = page.items.where((c) => c.unread > 0);
      final read = page.items.where((c) => c.unread == 0);
      return [...unread, ...read].take(3).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _load() async {
    final recentFuture = _fetchRecent();
    try {
      final data = await WhatsAppService.overview();
      final recent = await recentFuture;
      if (!mounted) return;
      setState(() {
        _data = data;
        _recent = recent;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      await recentFuture;
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<String?> _sheet(Widget child) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => child,
  );

  Future<void> _connect() async {
    final message = await _sheet(const WhatsAppConnectSheet());
    if (message == null || !mounted) return;
    showToast(context, message);
    _load();
  }

  Future<void> _openNumber(WaNumber n) async {
    final message = await _sheet(WhatsAppNumberSheet(number: n));
    if (message == null || !mounted) return;
    showToast(context, message);
    _load();
  }

  WaNumber _defaultNumber(WaOverview d) =>
      d.numbers.firstWhere((n) => n.isDefault, orElse: () => d.numbers.first);

  /// "Send a test" lives in the number's actions, so open them for the default
  /// number (or the connect sheet when there is none yet).
  void _sendTest() {
    final d = _data;
    if (d == null) return;
    if (!d.hasNumbers) {
      _connect();
      return;
    }
    _openNumber(_defaultNumber(d));
  }

  Future<void> _addContact() async {
    final message = await _sheet(const WhatsAppContactSheet());
    if (message == null || !mounted) return;
    showToast(context, message);
    _load();
  }

  Future<void> _newCampaign() async {
    final created = await Navigator.of(context).push<WaCampaign>(
      MaterialPageRoute(builder: (_) => const WhatsAppCampaignCreateScreen()),
    );
    if (created == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WhatsAppCampaignDetailScreen(campaignId: created.id),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openInbox([InboxFilter filter = InboxFilter.all]) async {
    final switchTab = widget.onOpenInbox;
    if (switchTab != null) {
      switchTab(filter);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WhatsAppInboxScreen(initialFilter: filter),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openChat(WaConversation c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => WhatsAppChatScreen(conversation: c)),
    );
    if (mounted) _load();
  }

  Future<void> _pullFromMeta() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final message = await WhatsAppService.refreshNumbers();
      if (mounted) showToast(context, message);
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Widget _failure(Object error) {
    final access = accessProblem(error);
    if (access != null) {
      // Not allowed: no retry button, the answer will not change by asking again.
      return StateView(
        icon: access.icon,
        title: access.title,
        text: access.text,
      );
    }
    return StateView.error(
      title: 'Could not load WhatsApp',
      text: friendlyException(error).message,
      onRetry: () {
        setState(() => _loading = true);
        _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final error = _error;

    return Scaffold(
      backgroundColor: surface,
      body: _loading && data == null
          ? const SkeletonList(count: 3, itemHeight: 110, headerHeight: 150)
          : error != null && data == null
          ? Center(child: SingleChildScrollView(child: _failure(error)))
          : ContentWidth(
              child: RefreshIndicator(
                color: brand,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [if (data != null) ..._content(data)],
                ),
              ),
            ),
    );
  }

  List<Widget> _content(WaOverview d) {
    // The setup guide: one step at a time until all three are done.
    final done = [
      d.hasNumbers,
      d.numbers.any((n) => n.isRegistered),
      d.conversations.total > 0,
    ];
    final next = done.indexOf(false);

    return [
      FadeIn(child: _HeroCard(overview: d, number: _heroNumber(d))),
      if (next != -1) ...[
        const SizedBox(height: 14),
        FadeIn(
          delay: 40,
          child: _SetupCard(
            done: done,
            next: next,
            onConnect: _connect,
            onTurnOnSending: () {
              final pending = d.numbers.where((n) => !n.isRegistered);
              if (pending.isNotEmpty) _openNumber(pending.first);
            },
            onSendTest: _sendTest,
          ),
        ),
      ],
      const SizedBox(height: 14),
      if (d.hasNumbers) ...[
        FadeIn(
          delay: 60,
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Open chats',
                  value: d.conversations.open,
                  icon: Icons.forum_rounded,
                  onTap: () => _openInbox(InboxFilter.open),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Unread',
                  value: d.conversations.unread,
                  icon: Icons.mark_chat_unread_rounded,
                  highlight: d.conversations.unread > 0,
                  onTap: () => _openInbox(InboxFilter.unread),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FadeIn(
          delay: 100,
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Received today',
                  value: d.inboundToday,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Sent today',
                  value: d.outboundToday,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FadeIn(
          delay: 140,
          child: Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.campaign_rounded,
                  label: 'New campaign',
                  onTap: _newCampaign,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Add contact',
                  onTap: _addContact,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.send_rounded,
                  label: 'Send test',
                  onTap: _sendTest,
                ),
              ),
            ],
          ),
        ),
      ],
      if (_recent.isNotEmpty) ...[
        SectionTitle(
          'Recent chats',
          trailing: TextButton(
            onPressed: () => _openInbox(),
            child: const Text('See all'),
          ),
        ),
        for (var i = 0; i < _recent.length; i++)
          FadeIn(
            delay: 180 + i * 50,
            child: _RecentChatTile(
              conversation: _recent[i],
              onTap: () => _openChat(_recent[i]),
            ),
          ),
      ],
      if (d.hasNumbers) ...[
        const SectionTitle('Connected numbers'),
        for (var i = 0; i < d.numbers.length; i++)
          FadeIn(
            delay: 220 + i * 60,
            child: _NumberTile(
              number: d.numbers[i],
              onTap: () => _openNumber(d.numbers[i]),
            ),
          ),
      ],
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Connect number'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _refreshing ? null : _pullFromMeta,
              icon: _refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    ];
  }

  WaNumber? _heroNumber(WaOverview d) => d.hasNumbers ? _defaultNumber(d) : null;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.overview, required this.number});

  final WaOverview overview;

  /// The number whose health is shown (the default one). Null: none connected.
  final WaNumber? number;

  @override
  Widget build(BuildContext context) {
    final count = overview.numbers.length;
    final n = number;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [royalIndigo, royalViolet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const ExcludeSemantics(
                  child: Icon(Icons.chat_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'WhatsApp',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'No number connected yet'
                          : count == 1
                          ? '1 number connected'
                          : '$count numbers connected',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (n != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    n.displayNumber,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  _HeroDot(
                    n.isRegistered ? 'Sending on' : 'Sending off',
                    n.isRegistered ? good : warn,
                  ),
                  if (n.quality.isNotEmpty)
                    _HeroDot(
                      'Quality ${n.quality[0].toUpperCase()}${n.quality.substring(1).toLowerCase()}',
                      _qualityColor(n.quality),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroDot extends StatelessWidget {
  const _HeroDot(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(Icons.circle, size: 9, color: color)),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A short checklist that guides the first minutes: connect, turn on sending,
/// get the first chat. It disappears once all three are done.
class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.done,
    required this.next,
    required this.onConnect,
    required this.onTurnOnSending,
    required this.onSendTest,
  });

  final List<bool> done;

  /// Index of the first step that is not done yet.
  final int next;
  final VoidCallback onConnect;
  final VoidCallback onTurnOnSending;
  final VoidCallback onSendTest;

  static const _titles = [
    'Connect your WhatsApp number',
    'Turn on sending',
    'Get your first chat',
  ];

  static const _hints = [
    'Add the ids and token from Meta. It takes a minute.',
    'Register the number once so you can send messages.',
    'Message your number from another phone. The chat shows up in Inbox.',
  ];

  @override
  Widget build(BuildContext context) {
    final finished = done.where((d) => d).length;
    final (label, action) = switch (next) {
      0 => ('Connect your number', onConnect),
      1 => ('Turn on sending', onTurnOnSending),
      _ => ('Send a test message', onSendTest),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Get started',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ink,
                    ),
                  ),
                ),
              ),
              InfoChip('$finished of 3 done', color: brand),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _titles.length; i++)
            Semantics(
              label: '${_titles[i]}, ${done[i] ? 'done' : 'not done yet'}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      done[i]
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color: done[i] ? good : muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titles[i],
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: done[i] ? muted : ink,
                              decoration: done[i]
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (i == next)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _hints[i],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: muted,
                                  height: 1.35,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: action, child: Text(label)),
          ),
        ],
      ),
    );
  }
}

/// A big, tappable shortcut: icon over a short label.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExcludeSemantics(
                child: Icon(icon, size: 20, color: brand),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the latest chats: avatar, name, last message, time, unread count.
class _RecentChatTile extends StatelessWidget {
  const _RecentChatTile({required this.conversation, required this.onTap});

  final WaConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unread > 0;
    return Pressable(
      onTap: onTap,
      child: Semantics(
        label:
            '${c.contact.title}${unread ? ', ${c.unread} unread' : ''}: '
            '${c.preview.isEmpty ? 'No messages yet' : c.preview}',
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: cardDecoration(),
          child: Row(
            children: [
              ContactAvatar(name: c.contact.title, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.contact.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          shortWhen(c.lastMessageAt),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: unread ? brand : muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.preview.isEmpty ? 'No messages yet' : c.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: unread ? ink : muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c.unread > 99 ? '99+' : '${c.unread}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color _qualityColor(String quality) {
  switch (quality.toUpperCase()) {
    case 'GREEN':
      return good;
    case 'YELLOW':
      return warn;
    case 'RED':
      return bad;
    default:
      return muted;
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({required this.number, required this.onTap});

  final WaNumber number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quality = _qualityColor(number.quality);
    final name = number.verifiedName.isEmpty
        ? number.wabaName
        : number.verifiedName;
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: good.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const ExcludeSemantics(
                child: Icon(Icons.phone_android_rounded, color: good),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number.displayNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  if (name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (number.status.isNotEmpty)
                  Text(
                    number.status.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                if (number.quality.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: quality),
                      const SizedBox(width: 4),
                      Text(
                        number.quality[0].toUpperCase() +
                            number.quality.substring(1).toLowerCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: quality,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
