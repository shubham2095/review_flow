import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/count_up.dart';
import '../widgets/fade_in.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import 'whatsapp_connect_sheet.dart';
import 'whatsapp_contacts_screen.dart';
import 'whatsapp_inbox_screen.dart';
import 'whatsapp_templates_screen.dart';
import 'whatsapp_number_sheet.dart';

/// WhatsApp home: connected numbers and today's numbers. Later phases add the
/// inbox, contacts, templates and campaigns beneath this summary.
class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  WaOverview? _data;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await WhatsAppService.overview();
      if (!mounted) return;
      setState(() {
        _data = data;
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

  bool _refreshing = false;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
    if (message == null) return;
    _snack(message);
    _load();
  }

  Future<void> _openContacts() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const WhatsAppContactsScreen()),
  );

  Future<void> _openTemplates() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const WhatsAppTemplatesScreen()),
  );

  Future<void> _openInbox() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const WhatsAppInboxScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _openNumber(WaNumber n) async {
    final message = await _sheet(WhatsAppNumberSheet(number: n));
    if (message == null) return;
    _snack(message);
    _load();
  }

  Future<void> _pullFromMeta() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      _snack(await WhatsAppService.refreshNumbers());
      await _load();
    } catch (e) {
      _snack(errorLine(e));
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
          : RefreshIndicator(
              color: brand,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [if (data != null) ..._content(data)],
              ),
            ),
    );
  }

  List<Widget> _content(WaOverview d) {
    return [
      FadeIn(child: _HeroCard(overview: d)),
      const SizedBox(height: 14),
      if (d.hasNumbers) ...[
        FadeIn(
          delay: 60,
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Open chats',
                  value: d.conversations.open,
                  icon: Icons.forum_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'Unread',
                  value: d.conversations.unread,
                  icon: Icons.mark_chat_unread_rounded,
                  highlight: d.conversations.unread > 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FadeIn(
          delay: 120,
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Received today',
                  value: d.inboundToday,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'Sent today',
                  value: d.outboundToday,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ),
        const _Title('Connected numbers'),
        for (var i = 0; i < d.numbers.length; i++)
          FadeIn(
            delay: 160 + i * 60,
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
      const _Title('Coming next'),
      _LinkTile(
        icon: Icons.forum_rounded,
        title: 'Inbox',
        text: 'Read your customer chats',
        badge: d.conversations.unread,
        onTap: _openInbox,
      ),
      _LinkTile(
        icon: Icons.contacts_rounded,
        title: 'Contacts',
        text: 'Tags, hot leads and blocked numbers',
        onTap: _openContacts,
      ),
      _LinkTile(
        icon: Icons.description_rounded,
        title: 'Templates',
        text: 'Message templates and their approval status',
        onTap: _openTemplates,
      ),
      const _SoonTile(
        Icons.campaign_rounded,
        'Campaigns',
        'Bulk messages and delivery results',
      ),
    ];
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.overview});

  final WaOverview overview;

  @override
  Widget build(BuildContext context) {
    final count = overview.numbers.length;
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
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.chat_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WhatsApp',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
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
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tone = highlight ? brand : muted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(height: 10),
          CountUp(
            value: value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ink,
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
              child: const Icon(Icons.phone_android_rounded, color: good),
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

class _SoonTile extends StatelessWidget {
  const _SoonTile(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: muted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'SOON',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String text;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Text(
                    text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }
}
