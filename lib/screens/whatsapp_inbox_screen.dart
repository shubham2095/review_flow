import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/offline_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/text_scale.dart';
import '../widgets/wa_tab_scope.dart';
import '../widgets/wa_ui.dart';
import 'whatsapp_chat_screen.dart';

/// "Today 3:05 PM", "Yesterday", "12 Nov": the short time shown in lists.
String shortWhen(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
  if (diff == 1) return 'Yesterday';
  return d.year == now.year
      ? fmtDate(d).replaceFirst(' ${d.year}', '')
      : fmtDate(d);
}

/// Which chats the Inbox shows. [open] is asked from the server; [unread] and
/// [hot] narrow down the chats already loaded (the server has no such filter).
enum InboxFilter { all, unread, hot, open }

/// The icon and word for a preview that is just a media marker such as
/// "[Image]" or "[Document]". Null for ordinary text.
({IconData icon, String label})? mediaPreview(String preview) {
  final m = RegExp(
    r'^\[(image|photo|video|audio|voice|document|sticker|location|contact)[^\]]*\]$',
    caseSensitive: false,
  ).firstMatch(preview.trim());
  if (m == null) return null;
  switch (m.group(1)!.toLowerCase()) {
    case 'image':
    case 'photo':
      return (icon: Icons.photo_outlined, label: 'Photo');
    case 'video':
      return (icon: Icons.videocam_outlined, label: 'Video');
    case 'audio':
    case 'voice':
      return (icon: Icons.mic_none_rounded, label: 'Voice message');
    case 'document':
      return (icon: Icons.insert_drive_file_outlined, label: 'Document');
    case 'sticker':
      return (icon: Icons.emoji_emotions_outlined, label: 'Sticker');
    case 'location':
      return (icon: Icons.place_outlined, label: 'Location');
    default:
      return (icon: Icons.person_outline_rounded, label: 'Contact');
  }
}

/// Conversation list: search, filters (All, Unread, Hot, Open), unread and hot
/// badges, whether the 24-hour reply window is open, and swipe to mark read.
/// Refreshes itself while visible.
class WhatsAppInboxScreen extends StatefulWidget {
  const WhatsAppInboxScreen({
    super.key,
    this.embedded = false,
    this.onUnreadMayHaveChanged,
    this.initialFilter = InboxFilter.all,
    this.filterRequest,
  });

  /// Inside the WhatsApp tabs: no AppBar of its own (the shell has the top
  /// bar) and no second offline banner.
  final bool embedded;

  /// Called after a chat is closed or marked read, so the shell can refresh its
  /// unread badge.
  final VoidCallback? onUnreadMayHaveChanged;

  /// The filter to start on (for example Unread from the Home stat tile).
  final InboxFilter initialFilter;

  /// Another part of the app (the Home tab) asks for a filter by setting a
  /// value here. The Inbox applies it and clears it.
  final ValueNotifier<InboxFilter?>? filterRequest;

  @override
  State<WhatsAppInboxScreen> createState() => _WhatsAppInboxScreenState();
}

class _WhatsAppInboxScreenState extends State<WhatsAppInboxScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  Timer? _poll;

  List<WaConversation> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _foreground = true;
  late InboxFilter _filter = widget.initialFilter;

  /// Chats that arrived (or got more unread) while the person was scrolled down.
  int _newCount = 0;

  /// False while this screen is a tab the person has switched away from: it
  /// then does not poll, and catches up when the tab is shown again.
  bool _active = true;
  Object? _error;
  int _generation = 0;

  bool get _serverFilter => _filter == InboxFilter.open;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nowActive = WaTabScope.isActive(context);
    final becameVisible = nowActive && !_active;
    _active = nowActive;
    if (becameVisible) _silentRefresh();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    // A filter asked for before this tab was first shown (the tab is built
    // lazily): take it now.
    final pending = widget.filterRequest?.value;
    if (pending != null) {
      _filter = pending;
      widget.filterRequest!.value = null;
    }
    widget.filterRequest?.addListener(_onFilterRequest);
    _load();
    _poll = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _silentRefresh(),
    );
  }

  @override
  void didUpdateWidget(covariant WhatsAppInboxScreen old) {
    super.didUpdateWidget(old);
    if (old.filterRequest != widget.filterRequest) {
      old.filterRequest?.removeListener(_onFilterRequest);
      widget.filterRequest?.addListener(_onFilterRequest);
    }
  }

  @override
  void dispose() {
    widget.filterRequest?.removeListener(_onFilterRequest);
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _silentRefresh();
  }

  void _onFilterRequest() {
    final request = widget.filterRequest;
    final f = request?.value;
    if (request == null || f == null) return;
    request.value = null;
    _setFilter(f);
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) _loadMore();
    if (_newCount > 0 && _scroll.offset < 100) {
      setState(() => _newCount = 0);
    }
  }

  void _setFilter(InboxFilter f) {
    if (f == _filter) {
      _toTop();
      return;
    }
    final serverChanges = _serverFilter || f == InboxFilter.open;
    setState(() {
      _filter = f;
      _newCount = 0;
    });
    if (serverChanges) {
      _restart();
    } else {
      _toTop();
    }
  }

  void _toTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<WaConversationPage> _fetch(int page) => WhatsAppService.conversations(
    search: _search.text.trim(),
    status: _serverFilter ? 'open' : null,
    page: page,
  );

  Future<void> _load() async {
    final gen = ++_generation;
    try {
      final res = await _fetch(1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = res.items;
        _page = res.page;
        _hasMore = res.hasMore;
        _error = null;
        _loading = false;
        _newCount = 0;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Keeps the first page fresh without a spinner or a scroll jump. Pages the
  /// person already scrolled to are left alone. When chats arrive while they
  /// are scrolled down, a "N new" pill offers to jump back up.
  Future<void> _silentRefresh() async {
    if (!mounted || !_active || !_foreground || _loading || _loadingMore) {
      return;
    }
    final gen = _generation;
    try {
      final res = await _fetch(1);
      if (!mounted || gen != _generation || _loadingMore) return;
      final before = {for (final c in _items) c.id: c.unread};
      final arrived = res.items
          .where((c) => !before.containsKey(c.id) || c.unread > before[c.id]!)
          .length;
      setState(() {
        final fresh = res.items.map((c) => c.id).toSet();
        final older = _page > 1
            ? _items.skip(res.items.length).where((c) => !fresh.contains(c.id))
            : const <WaConversation>[];
        _items = [...res.items, ...older];
        if (_page == 1) _hasMore = res.hasMore;
        _error = null;
        if (arrived > 0 && _scroll.hasClients && _scroll.offset > 200) {
          _newCount += arrived;
        }
      });
    } catch (_) {
      // A failed background refresh keeps what is on screen.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final gen = _generation;
    try {
      final res = await _fetch(_page + 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        final have = _items.map((c) => c.id).toSet();
        _items = [..._items, ...res.items.where((c) => !have.contains(c.id))];
        _page = res.page;
        _hasMore = res.hasMore;
      });
    } catch (_) {
      // The next scroll tries again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _restart() {
    setState(() => _loading = true);
    _load();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _restart);
  }

  Future<void> _open(WaConversation c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => WhatsAppChatScreen(conversation: c)),
    );
    // The chat marked itself read: reflect that and pick up newer messages.
    if (mounted) {
      setState(() {});
      _silentRefresh();
      widget.onUnreadMayHaveChanged?.call();
    }
  }

  /// Swipe (or the screen reader action) marks a chat read. The row itself
  /// stays, so it always returns false to the swipe.
  Future<bool> _markRead(WaConversation c) async {
    if (c.unread == 0) return false;
    try {
      await WhatsAppService.markRead(c.id);
      if (mounted) {
        HapticFeedback.selectionClick();
        setState(() => c.unread = 0);
        widget.onUnreadMayHaveChanged?.call();
      }
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    }
    return false;
  }

  /// What is shown for the current filter.
  List<WaConversation> get _visible {
    switch (_filter) {
      case InboxFilter.unread:
        return _items.where((c) => c.unread > 0).toList();
      case InboxFilter.hot:
        return _items.where((c) => c.contact.isHot).toList();
      case InboxFilter.all:
      case InboxFilter.open:
        return _items;
    }
  }

  Widget _empty(bool searching) {
    final IconData icon;
    final String title;
    final String text;
    if (searching) {
      icon = Icons.search_off_rounded;
      title = 'No chats found';
      text = 'Try a different name or number.';
    } else {
      switch (_filter) {
        case InboxFilter.unread:
          icon = Icons.done_all_rounded;
          title = 'You are all caught up';
          text = 'No unread chats right now.';
        case InboxFilter.hot:
          icon = Icons.local_fire_department_outlined;
          title = 'No hot leads right now';
          text = 'Chats the AI marks as hot leads show up here.';
        case InboxFilter.open:
          icon = Icons.forum_outlined;
          title = 'No open chats';
          text = 'Chats that are still open will be listed here.';
        case InboxFilter.all:
          icon = Icons.forum_outlined;
          title = 'No chats yet';
          text =
              'When a customer messages your WhatsApp number, the chat shows up here.';
      }
    }
    return StateView(icon: icon, title: title, text: text);
  }

  Widget _body() {
    final error = _error;
    if (_loading && _items.isEmpty) {
      return const SkeletonList(count: 6, itemHeight: 96, headerHeight: null);
    }
    if (error != null && _items.isEmpty) {
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
                  title: 'Could not load chats',
                  text: friendlyException(error).message,
                  onRetry: _restart,
                ),
        ),
      );
    }

    final visible = _visible;
    final searching = _search.text.trim().isNotEmpty;
    final narrowing =
        _filter == InboxFilter.unread || _filter == InboxFilter.hot;

    // Unread and Hot only look at chats already loaded: keep loading older
    // pages until a screenful matches (or there are no more).
    if (narrowing && visible.length < 8 && _hasMore && !_loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }

    final stillLooking = visible.isEmpty && (_hasMore || _loadingMore);

    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: visible.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (stillLooking)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _empty(searching),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: visible.length + (_loadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= visible.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final c = visible[i];
                return FadeIn(
                  delay: i < 8 ? i * 30 : 0,
                  child: Dismissible(
                    key: ValueKey('chat-${c.id}'),
                    direction: c.unread > 0
                        ? DismissDirection.startToEnd
                        : DismissDirection.none,
                    confirmDismiss: (_) => _markRead(c),
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.done_all_rounded, color: brand),
                          const SizedBox(width: 8),
                          Text(
                            'Mark read',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: _ChatTile(
                      conversation: c,
                      onTap: () => _open(c),
                      onMarkRead: () => _markRead(c),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      InboxFilter.all: 'All',
      InboxFilter.unread: 'Unread',
      InboxFilter.hot: 'Hot',
      InboxFilter.open: 'Open',
    };
    return Scaffold(
      backgroundColor: surface,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                'Inbox',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              foregroundColor: ink,
            ),
      body: ContentWidth(
        child: Column(
          children: [
            if (!widget.embedded) const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search name or number',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            _restart();
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: textScaled(context, 52),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  for (final f in InboxFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(labels[f]!),
                        selected: _filter == f,
                        onSelected: (_) => _setFilter(f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  _body(),
                  if (_newCount > 0)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _NewPill(count: _newCount, onTap: _toTop),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 new" pill that jumps back to the top of the list.
class _NewPill extends StatelessWidget {
  const _NewPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: true,
      label: '$count new, go to top',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: brand,
        elevation: 4,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '$count new',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
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

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.conversation,
    required this.onTap,
    required this.onMarkRead,
  });

  final WaConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unread > 0;
    final media = mediaPreview(c.preview);
    final previewText = c.preview.isEmpty ? 'No messages yet' : c.preview;

    final spoken = StringBuffer(c.contact.title);
    if (unread) spoken.write(', ${c.unread} unread');
    if (c.contact.isHot) spoken.write(', hot lead');
    spoken.write(': ${media?.label ?? previewText}');
    spoken.write(', ${c.windowOpen ? 'you can reply' : 'reply window closed'}');

    return Pressable(
      onTap: onTap,
      child: Semantics(
        label: spoken.toString(),
        customSemanticsActions: {
          if (unread)
            const CustomSemanticsAction(label: 'Mark as read'): onMarkRead,
        },
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ContactAvatar(name: c.contact.title),
                  if (c.contact.isHot)
                    const Positioned(
                      right: -3,
                      bottom: -3,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          size: 15,
                          color: bad,
                        ),
                      ),
                    ),
                ],
              ),
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
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (media != null) ...[
                          Icon(media.icon, size: 15, color: muted),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            media?.label ?? previewText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: unread ? ink : muted,
                            ),
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          c.windowOpen
                              ? Icons.schedule_rounded
                              : Icons.lock_clock_rounded,
                          size: 12,
                          color: c.windowOpen ? good : muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            c.windowOpen ? 'Can reply' : 'Reply window closed',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: c.windowOpen ? good : muted,
                            ),
                          ),
                        ),
                        if (c.agentName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '· ${c.agentName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ],
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
