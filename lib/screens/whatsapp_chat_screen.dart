import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';

/// One chat: messages oldest to newest (newest at the bottom), older ones load
/// as you scroll up, new ones arrive on their own while the screen is open.
class WhatsAppChatScreen extends StatefulWidget {
  const WhatsAppChatScreen({super.key, required this.conversation});

  final WaConversation conversation;

  @override
  State<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends State<WhatsAppChatScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  Timer? _poll;

  /// Newest first, so the reversed list draws the newest at the bottom.
  List<WaMessage> _messages = [];
  String? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _foreground = true;
  Object? _error;

  WaConversation get _c => widget.conversation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  void _onScroll() {
    // The list is reversed: the "end" is the oldest message.
    if (_scroll.position.extentAfter < 300) _loadOlder();
  }

  Future<void> _load() async {
    try {
      final page = await WhatsAppService.messages(_c.id);
      if (!mounted) return;
      setState(() {
        _messages = page.items;
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _error = null;
        _loading = false;
      });
      _markRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Picks up new messages and status changes (sent, delivered, read) without
  /// touching what is already scrolled into view.
  Future<void> _refresh() async {
    if (!mounted || !_foreground || _loading || _loadingOlder) return;
    try {
      final page = await WhatsAppService.messages(_c.id);
      if (!mounted || _loadingOlder) return;
      final fresh = page.items.map((m) => m.id).toSet();
      final arrived = page.items.any(
        (m) => !_messages.any((o) => o.id == m.id),
      );
      setState(() {
        _messages = [
          ...page.items,
          ..._messages.where((m) => !fresh.contains(m.id)),
        ];
        _error = null;
      });
      if (arrived) _markRead();
    } catch (_) {
      // Keep what is on screen; the next tick tries again.
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _loading || _cursor == null) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await WhatsAppService.messages(_c.id, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        final have = _messages.map((m) => m.id).toSet();
        _messages = [
          ..._messages,
          ...page.items.where((m) => !have.contains(m.id)),
        ];
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      // The next scroll tries again.
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _markRead() async {
    if (_c.unread == 0) return;
    try {
      await WhatsAppService.markRead(_c.id);
      if (mounted) setState(() => _c.unread = 0);
    } catch (_) {
      // Not being able to mark read must not get in the way of reading.
    }
  }

  Widget _body() {
    final error = _error;
    if (_loading) {
      return const SkeletonList(count: 6, itemHeight: 56, headerHeight: 0);
    }
    if (error != null && _messages.isEmpty) {
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
                  title: 'Could not load messages',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const StateView(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: _messages.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final m = _messages[i];
        // _messages is newest first, so the next index is the older message.
        final older = i + 1 < _messages.length ? _messages[i + 1] : null;
        final newDay =
            m.createdAt != null &&
            (older?.createdAt == null ||
                !_sameDay(m.createdAt!, older!.createdAt!));
        return Column(
          children: [
            if (newDay) _DayChip(m.createdAt!),
            _Bubble(message: m),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEAE2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    _c.contact.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ink,
                    ),
                  ),
                ),
                if (_c.contact.isHot) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: bad,
                  ),
                ],
              ],
            ),
            if (_c.contact.name.trim().isNotEmpty &&
                _c.contact.phone.isNotEmpty)
              Text(
                _c.contact.phone,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _body()),
          _WindowBar(conversation: _c),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _clock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String _size(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.date);

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = _sameDay(date, now)
        ? 'Today'
        : _sameDay(date, now.subtract(const Duration(days: 1)))
        ? 'Yesterday'
        : fmtDate(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
      ),
    );
  }
}

class _WindowBar extends StatelessWidget {
  const _WindowBar({required this.conversation});

  final WaConversation conversation;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final until = c.windowExpiresAt;
    final text = c.windowOpen
        ? (until == null
              ? 'You can reply to this chat.'
              : 'You can reply until ${fmtDateTime(until)}.')
        : 'The 24-hour reply window is closed. Only an approved template can '
              'start the chat again.';
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Icon(
            c.windowOpen ? Icons.schedule_rounded : Icons.lock_clock_rounded,
            size: 16,
            color: c.windowOpen ? good : muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: c.windowOpen ? good : muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final WaMessage message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.outbound;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final text = m.body.trim();
    final hasMedia = m.attachments.isNotEmpty;
    final showText =
        text.isNotEmpty &&
        // A caption is shown under the media, not twice.
        !(hasMedia && m.attachments.every((a) => a.caption.trim() == text));

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFD9FDD3) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine && m.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  m.senderName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: brandDeep,
                  ),
                ),
              ),
            for (final a in m.attachments) _AttachmentView(attachment: a),
            if (showText)
              Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.35,
                  color: ink,
                ),
              )
            else if (!hasMedia)
              Text(
                m.type.isEmpty ? 'Message' : '[${m.type} message]',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: muted,
                ),
              ),
            if (m.failed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  m.errorMessage.isEmpty
                      ? 'This message could not be delivered.'
                      : m.errorMessage,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: bad,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (m.createdAt != null)
                  Text(
                    _clock(m.createdAt!),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: muted,
                    ),
                  ),
                if (mine) ...[const SizedBox(width: 4), _Ticks(m.status)],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Ticks extends StatelessWidget {
  const _Ticks(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'read':
        return const Icon(
          Icons.done_all_rounded,
          size: 15,
          color: Color(0xFF2196F3),
        );
      case 'delivered':
        return const Icon(Icons.done_all_rounded, size: 15, color: muted);
      case 'failed':
        return const Icon(Icons.error_outline_rounded, size: 15, color: bad);
      default:
        return const Icon(Icons.done_rounded, size: 15, color: muted);
    }
  }
}

class _AttachmentView extends StatelessWidget {
  const _AttachmentView({required this.attachment});

  final WaAttachment attachment;

  Future<void> _openExternal(BuildContext context) async {
    final ok =
        attachment.url.isNotEmpty &&
        await launchUrl(
          Uri.parse(attachment.url),
          mode: LaunchMode.externalApplication,
        );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    if (a.url.isEmpty) {
      return _FileTile(
        icon: Icons.broken_image_outlined,
        title: a.fileName.isEmpty ? 'Media not available' : a.fileName,
        subtitle: 'This file was not saved',
        onTap: null,
      );
    }
    if (a.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => _FullImage(url: a.url)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              a.url,
              fit: BoxFit.cover,
              height: 200,
              width: double.infinity,
              loadingBuilder: (_, child, p) => p == null
                  ? child
                  : const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (_, _, _) => const SizedBox(
                height: 120,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, color: muted),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final icon = switch (a.type) {
      'video' => Icons.play_circle_outline_rounded,
      'audio' => Icons.headphones_rounded,
      _ => Icons.insert_drive_file_outlined,
    };
    final label = a.fileName.isEmpty
        ? (a.type.isEmpty
              ? 'File'
              : a.type[0].toUpperCase() + a.type.substring(1))
        : a.fileName;
    return _FileTile(
      icon: icon,
      title: label,
      subtitle: [
        _size(a.size),
        'Tap to open',
      ].where((s) => s.isNotEmpty).join(' · '),
      onTap: () => _openExternal(context),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: brand),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: ink,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullImage extends StatelessWidget {
  const _FullImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            url,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
