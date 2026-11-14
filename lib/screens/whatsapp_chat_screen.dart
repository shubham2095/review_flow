import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
import 'whatsapp_template_picker.dart';

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
  final _input = TextEditingController();
  bool _sending = false;
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
    _input.dispose();
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
      final newOnes = page.items.where(
        (m) => !_messages.any((o) => o.id == m.id),
      );
      final arrived = newOnes.isNotEmpty;
      final inbound = newOnes.where((m) => !m.outbound).toList();
      setState(() {
        // A customer message re-opens the 24-hour window (the server decides
        // for real when a reply is sent).
        if (inbound.isNotEmpty && inbound.first.createdAt != null) {
          final at = inbound.first.createdAt!;
          final until = at.add(const Duration(hours: 24));
          if (until.isAfter(DateTime.now())) {
            _c.windowOpen = true;
            _c.windowExpiresAt = until;
          }
        }
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

  /// True while the 24-hour window is open (also checked against the clock, so
  /// the composer switches to templates the moment it lapses).
  bool get _canReply {
    final until = _c.windowExpiresAt;
    return _c.windowOpen && (until == null || until.isAfter(DateTime.now()));
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// A message the server accepted goes to the bottom straight away.
  void _added(WaMessage m) {
    setState(() => _messages = [m, ..._messages]);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await WhatsAppService.sendText(_c.id, text);
      if (!mounted) return;
      _input.clear();
      _added(m);
    } catch (e) {
      // The text stays in the box so nothing typed is lost.
      HapticFeedback.lightImpact();
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickTemplate() async {
    if (_sending) return;
    final t = await showModalBottomSheet<WaTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const WhatsAppTemplatePicker(),
    );
    if (t == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send "${t.name}"?'),
        content: Text(
          t.body.isEmpty
              ? 'This template goes to ${_c.contact.title}.'
              : t.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      _added(await WhatsAppService.sendTemplate(_c.id, t));
    } catch (e) {
      HapticFeedback.lightImpact();
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static const _maxBytes = 16 * 1024 * 1024;

  Future<void> _attach() async {
    if (_sending) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Photo from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_rounded),
              title: const Text('Document'),
              onTap: () => Navigator.pop(ctx, 'document'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    List<int>? bytes;
    var name = '';
    var type = 'image';
    try {
      if (choice == 'document') {
        final file = await FilePicker.pickFile();
        if (file == null) return;
        bytes = await file.readAsBytes();
        name = file.name;
        type = 'document';
      } else {
        final picker = ImagePicker();
        final XFile? picked;
        if (choice == 'video') {
          picked = await picker.pickVideo(source: ImageSource.gallery);
          type = 'video';
        } else {
          picked = await picker.pickImage(
            source: choice == 'camera'
                ? ImageSource.camera
                : ImageSource.gallery,
            maxWidth: 1920,
            imageQuality: 85,
          );
        }
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        name = picked.name;
      }
    } catch (_) {
      _snack(
        'Could not open that. Allow access for Eydia in your phone settings and try again.',
      );
      return;
    }
    if (bytes.isEmpty) {
      _snack('That file could not be read. Please pick another one.');
      return;
    }
    if (bytes.length > _maxBytes) {
      _snack('That file is over 16 MB. Choose a smaller one.');
      return;
    }
    if (!name.contains('.') && type == 'image') name = '$name.jpg';
    if (!mounted) return;

    final caption = await _askCaption(name);
    if (caption == null || !mounted) return;
    setState(() => _sending = true);
    try {
      _added(
        await WhatsAppService.sendMedia(
          _c.id,
          bytes: bytes,
          filename: name,
          mediaType: type,
          caption: caption,
        ),
      );
    } catch (e) {
      HapticFeedback.lightImpact();
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Returns the caption (possibly empty) to send, or null to cancel.
  Future<String?> _askCaption(String name) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send to ${_c.contact.title}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              maxLength: 1024,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _bubbleMenu(WaMessage m) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.body.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: bad),
              title: const Text('Delete from Eydia'),
              subtitle: const Text('The customer still keeps their copy'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.body.trim()));
      _snack('Copied.');
    } else if (choice == 'delete') {
      await _delete(m);
    }
  }

  Future<void> _delete(WaMessage m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text(
          'It is removed from Eydia only. It is not unsent: the customer still '
          'sees it on WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await WhatsAppService.deleteMessage(_c.id, m.id);
      if (mounted) {
        setState(
          () => _messages = _messages.where((x) => x.id != m.id).toList(),
        );
      }
    } catch (e) {
      _snack(errorLine(e));
    }
  }

  Widget _composer() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (!_canReply) {
      return Container(
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_clock_rounded, size: 16, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The 24-hour reply window is closed. Only an approved '
                    'template can start the chat again.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _pickTemplate,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.description_rounded, size: 18),
                label: const Text('Send a template'),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Attach',
            onPressed: _sending ? null : _attach,
            icon: const Icon(Icons.attach_file_rounded),
          ),
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              maxLength: 4096,
              enabled: !_sending,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type a message',
                counterText: '',
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: _sending || _input.text.trim().isEmpty
                ? null
                : _sendText,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
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
            _Bubble(message: m, onLongPress: () => _bubbleMenu(m)),
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
          _composer(),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onLongPress});

  final WaMessage message;
  final VoidCallback onLongPress;

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
      child: GestureDetector(
        onLongPress: onLongPress,
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
