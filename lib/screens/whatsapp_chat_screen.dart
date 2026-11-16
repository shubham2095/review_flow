import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../services/wa_drafts.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/linkified_text.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';
import 'whatsapp_contact_info_sheet.dart';
import 'whatsapp_template_picker.dart';

/// "Can reply · 3h 20m left", "Can reply · 12m left" or "Reply window closed".
/// [now] is a parameter so the wording can be tested.
String chatWindowLabel(DateTime? expiresAt, bool open, DateTime now) {
  if (!open || (expiresAt != null && !expiresAt.isAfter(now))) {
    return 'Reply window closed';
  }
  if (expiresAt == null) return 'Can reply';
  final left = expiresAt.difference(now);
  if (left.inHours >= 1) {
    return 'Can reply · ${left.inHours}h ${left.inMinutes % 60}m left';
  }
  if (left.inMinutes >= 1) return 'Can reply · ${left.inMinutes}m left';
  return 'Can reply · less than a minute left';
}

/// A reply that is being sent (or failed). It shows at the bottom straight
/// away and turns into the real message when the server accepts it.
class _PendingText {
  _PendingText(this.text) : createdAt = DateTime.now();

  final String text;
  final DateTime createdAt;
  bool sending = false;
  String? error;
}

/// One line of the chat: a real message or a pending reply.
class _ChatRow {
  _ChatRow.message(WaMessage m)
    : message = m,
      pending = null,
      outbound = m.outbound,
      at = m.createdAt,
      sender = m.senderName;

  _ChatRow.pending(_PendingText p)
    : message = null,
      pending = p,
      outbound = true,
      at = p.createdAt,
      sender = Session.current?.name ?? '';

  final WaMessage? message;
  final _PendingText? pending;
  final bool outbound;
  final DateTime? at;
  final String sender;
}

/// Neighbouring bubbles from the same side within five minutes are one group.
bool _sameGroup(_ChatRow a, _ChatRow b) {
  final x = a.at;
  final y = b.at;
  if (x == null || y == null) return false;
  return a.outbound == b.outbound &&
      a.sender == b.sender &&
      _sameDay(x, y) &&
      x.difference(y).abs() < const Duration(minutes: 5);
}

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
  Timer? _windowTicker;
  Timer? _draftTimer;

  /// Newest first, so the reversed list draws the newest at the bottom.
  List<WaMessage> _messages = [];

  /// Replies being sent or failed, newest first (they sit below every message).
  final List<_PendingText> _pending = [];
  String? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _foreground = true;
  Object? _error;

  /// Scrolled away from the newest message: show "jump to latest".
  bool _awayFromLatest = false;

  /// Customer messages that arrived while scrolled away.
  int _newWhileAway = 0;

  WaConversation get _c => widget.conversation;
  String get _userId => Session.current?.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
    // Keeps the "time left" in the title current.
    _windowTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _restoreDraft();
    WaDrafts.prune();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _windowTicker?.cancel();
    _draftTimer?.cancel();
    // Whatever is typed but not sent is kept for next time.
    final unsent = _input.text;
    if (unsent.trim().isNotEmpty) WaDrafts.save(_userId, _c.id, unsent);
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  Future<void> _restoreDraft() async {
    final saved = await WaDrafts.read(_userId, _c.id);
    if (saved == null || !mounted || _input.text.isNotEmpty) return;
    setState(() => _input.text = saved);
  }

  void _onTextChanged(String _) {
    setState(() {});
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), () {
      WaDrafts.save(_userId, _c.id, _input.text);
    });
  }

  void _onScroll() {
    // The list is reversed: the "end" is the oldest message.
    if (_scroll.position.extentAfter < 300) _loadOlder();
    final away = _scroll.offset > 300;
    if (away != _awayFromLatest) {
      setState(() {
        _awayFromLatest = away;
        if (!away) _newWhileAway = 0;
      });
    }
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
      final newOnes = page.items
          .where((m) => !_messages.any((o) => o.id == m.id))
          .toList();
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
        if (inbound.isNotEmpty && _awayFromLatest) {
          _newWhileAway += inbound.length;
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
    showToast(context, text);
  }

  /// A message the server accepted goes to the bottom straight away.
  void _added(WaMessage m) {
    setState(() => _messages = [m, ..._messages]);
    _jumpToLatest();
  }

  /// The text appears at the bottom at once (with a clock) and the box is free
  /// for the next message. If sending fails the text stays in a "Not sent"
  /// bubble with Retry, and the saved draft keeps it too.
  void _sendText() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _draftTimer?.cancel();
    _input.clear();
    final p = _PendingText(text);
    setState(() => _pending.insert(0, p));
    _jumpToLatest();
    _deliver(p);
  }

  Future<void> _deliver(_PendingText p) async {
    if (p.sending) return;
    setState(() {
      p.sending = true;
      p.error = null;
    });
    try {
      final m = await WhatsAppService.sendText(_c.id, p.text);
      if (!mounted) return;
      setState(() {
        _pending.remove(p);
        _messages = [m, ..._messages];
      });
      // Sent: the saved draft is done with, unless something new is being typed.
      if (_input.text.trim().isEmpty && _pending.isEmpty) {
        WaDrafts.clear(_userId, _c.id);
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        p.sending = false;
        p.error = errorLine(e);
      });
    }
  }

  void _discard(_PendingText p) {
    setState(() => _pending.remove(p));
    if (_input.text.trim().isEmpty && _pending.isEmpty) {
      WaDrafts.clear(_userId, _c.id);
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
    final choice = await showAppSheet<String>(
      context,
      title: 'Send a file',
      child: Builder(
        builder: (ctx) => Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            _AttachOption(
              icon: Icons.photo_library_rounded,
              label: 'Photo',
              color: const Color(0xFF7048E8),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            _AttachOption(
              icon: Icons.photo_camera_rounded,
              label: 'Camera',
              color: const Color(0xFFC2255C),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            _AttachOption(
              icon: Icons.videocam_rounded,
              label: 'Video',
              color: const Color(0xFF0C8599),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            _AttachOption(
              icon: Icons.insert_drive_file_rounded,
              label: 'Document',
              color: const Color(0xFF3B5BDB),
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

  void _showContactInfo() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => WhatsAppContactInfoSheet(conversation: _c),
    );
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
      padding: EdgeInsets.fromLTRB(4, 8, 8, 8 + bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Attach a file',
            onPressed: _sending ? null : _attach,
            icon: const Icon(Icons.attach_file_rounded),
          ),
          IconButton(
            tooltip: 'Send a template',
            onPressed: _sending ? null : _pickTemplate,
            icon: const Icon(Icons.description_outlined),
          ),
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              maxLength: 4096,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onTextChanged,
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
            tooltip: 'Send message',
            onPressed: _input.text.trim().isEmpty ? null : _sendText,
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final error = _error;
    if (_loading) {
      return const SkeletonList(count: 6, itemHeight: 82, headerHeight: null);
    }
    if (error != null && _messages.isEmpty && _pending.isEmpty) {
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
    if (_messages.isEmpty && _pending.isEmpty) {
      return const StateView(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
      );
    }
    // Pending replies first (they are the newest), then the real messages.
    final rows = [
      for (final p in _pending) _ChatRow.pending(p),
      for (final m in _messages) _ChatRow.message(m),
    ];
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: rows.length + (_loadingOlder ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= rows.length) {
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
        final row = rows[i];
        // rows are newest first: the next index is the older one.
        final older = i + 1 < rows.length ? rows[i + 1] : null;
        final newer = i > 0 ? rows[i - 1] : null;
        final newDay =
            row.at != null &&
            (older?.at == null || !_sameDay(row.at!, older!.at!));
        final first = older == null || newDay || !_sameGroup(row, older);
        final last = newer == null || !_sameGroup(newer, row);
        final m = row.message;
        final p = row.pending;
        return Column(
          children: [
            if (newDay) _DayChip(row.at!),
            if (m != null)
              _Bubble(
                message: m,
                first: first,
                last: last,
                onLongPress: () => _bubbleMenu(m),
              )
            else if (p != null)
              _PendingBubble(
                pending: p,
                first: first,
                last: last,
                onRetry: () => _deliver(p),
                onDiscard: () => _discard(p),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final contact = _c.contact;
    final label = chatWindowLabel(_c.windowExpiresAt, _c.windowOpen, DateTime.now());
    final closed = label == 'Reply window closed';
    final soon =
        !closed &&
        _c.windowExpiresAt != null &&
        _c.windowExpiresAt!.difference(DateTime.now()) <
            const Duration(hours: 2);
    final labelColor = closed ? muted : (soon ? warn : good);

    return Scaffold(
      backgroundColor: waChatBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        titleSpacing: 0,
        title: Semantics(
          button: true,
          label: 'Contact details for ${contact.title}. $label',
          excludeSemantics: true,
          child: InkWell(
            onTap: _showContactInfo,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: ink,
                          ),
                        ),
                      ),
                      if (contact.isHot) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: bad,
                        ),
                      ],
                    ],
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (contact.name.trim().isNotEmpty &&
                            contact.phone.isNotEmpty)
                          TextSpan(
                            text: '${contact.phone}  ·  ',
                            style: const TextStyle(color: muted),
                          ),
                        TextSpan(
                          text: label,
                          style: TextStyle(
                            color: labelColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Stack(
              children: [
                _body(),
                if (_awayFromLatest)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: FloatingActionButton.small(
                      heroTag: 'wa-jump-latest',
                      tooltip: _newWhileAway > 0
                          ? 'Jump to latest, $_newWhileAway new'
                          : 'Jump to latest',
                      backgroundColor: Colors.white,
                      foregroundColor: ink,
                      onPressed: _jumpToLatest,
                      child: Badge(
                        isLabelVisible: _newWhileAway > 0,
                        label: Text('$_newWhileAway'),
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        child: Semantics(
          header: true,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The bubble shape shared by real and pending messages: which side, how close
/// it sits to its neighbours, and the square corner at the bottom of a group.
class _BubbleShell extends StatelessWidget {
  const _BubbleShell({
    required this.mine,
    required this.first,
    required this.last,
    required this.spoken,
    required this.child,
    this.onLongPress,
    this.dim = false,
  });

  final bool mine;
  final bool first;
  final bool last;

  /// What a screen reader says before the content: who, when, status.
  final String spoken;
  final Widget child;
  final VoidCallback? onLongPress;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        container: true,
        label: spoken,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            margin: EdgeInsets.only(top: first ? 8 : 2, bottom: 2),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            decoration: BoxDecoration(
              color: (mine ? waBubbleOut : waBubbleIn).withValues(
                alpha: dim ? 0.7 : 1,
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(!mine && last ? 4 : 14),
                bottomRight: Radius.circular(mine && last ? 4 : 14),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.first,
    required this.last,
    required this.onLongPress,
  });

  final WaMessage message;
  final bool first;
  final bool last;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m.outbound;
    final text = m.body.trim();
    final hasMedia = m.attachments.isNotEmpty;
    final showText =
        text.isNotEmpty &&
        // A caption is shown under the media, not twice.
        !(hasMedia && m.attachments.every((a) => a.caption.trim() == text));

    final who = mine
        ? (m.senderName.isNotEmpty ? m.senderName : 'You')
        : 'Customer';
    final when = m.createdAt == null ? '' : ', ${_clock(m.createdAt!)}';
    final status = mine && m.status.isNotEmpty ? ', ${m.status}' : '';

    return _BubbleShell(
      mine: mine,
      first: first,
      last: last,
      spoken: '$who$when$status',
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The sender's name only above the first bubble of a group.
          if (mine && m.senderName.isNotEmpty && first)
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
            LinkifiedText(
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
    );
  }
}

/// A reply on its way (clock) or one that failed (red, with Retry and Discard).
class _PendingBubble extends StatelessWidget {
  const _PendingBubble({
    required this.pending,
    required this.first,
    required this.last,
    required this.onRetry,
    required this.onDiscard,
  });

  final _PendingText pending;
  final bool first;
  final bool last;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final p = pending;
    final failed = p.error != null;
    return _BubbleShell(
      mine: true,
      first: first,
      last: last,
      dim: !failed,
      spoken: failed
          ? 'You, ${_clock(p.createdAt)}, not sent'
          : 'You, ${_clock(p.createdAt)}, sending',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinkifiedText(
            p.text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.35,
              color: ink,
            ),
          ),
          if (failed) ...[
            const SizedBox(height: 6),
            Text(
              'Not sent: ${p.error}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: bad,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
                TextButton(
                  onPressed: onDiscard,
                  style: TextButton.styleFrom(foregroundColor: muted),
                  child: const Text('Discard'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _clock(p.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: muted,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.schedule_rounded, size: 14, color: muted),
              ],
            ),
          ],
        ],
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
        return const Icon(Icons.done_all_rounded, size: 15, color: waTick);
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
      showToast(context, 'Could not open this file.');
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
        child: Semantics(
          button: true,
          label: 'Photo. Open full screen',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => _FullImage(
                  url: a.url,
                  fileName: a.fileName,
                  mime: a.mime,
                ),
              ),
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

/// A photo full screen: pinch to zoom, and a Share button that sends the real
/// picture (not just a link) to another app.
class _FullImage extends StatefulWidget {
  const _FullImage({
    required this.url,
    required this.fileName,
    required this.mime,
  });

  final String url;
  final String fileName;
  final String mime;

  @override
  State<_FullImage> createState() => _FullImageState();
}

class _FullImageState extends State<_FullImage> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final res = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw const HttpException('download failed');
      }
      final dir = await getTemporaryDirectory();
      final raw = widget.fileName.isEmpty ? 'photo.jpg' : widget.fileName;
      final safe = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${dir.path}/eydia_$safe');
      await file.writeAsBytes(res.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: widget.mime.isEmpty ? 'image/jpeg' : widget.mime,
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) showToast(context, 'Could not share this photo. Try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Share photo',
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            widget.url,
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
