import 'dart:async';

import 'package:flutter/material.dart';
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

/// Conversation list: search, "open only" filter, unread and hot badges, and
/// whether the 24-hour reply window is open. Refreshes itself while visible.
class WhatsAppInboxScreen extends StatefulWidget {
  const WhatsAppInboxScreen({super.key});

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
  bool _openOnly = false;
  bool _foreground = true;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
    _poll = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
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

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) _loadMore();
  }

  Future<WaConversationPage> _fetch(int page) => WhatsAppService.conversations(
    search: _search.text.trim(),
    status: _openOnly ? 'open' : null,
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
  /// person already scrolled to are left alone.
  Future<void> _silentRefresh() async {
    if (!mounted || !_foreground || _loading || _loadingMore) return;
    final gen = _generation;
    try {
      final res = await _fetch(1);
      if (!mounted || gen != _generation || _loadingMore) return;
      setState(() {
        final fresh = res.items.map((c) => c.id).toSet();
        final older = _page > 1
            ? _items.skip(res.items.length).where((c) => !fresh.contains(c.id))
            : const <WaConversation>[];
        _items = [...res.items, ...older];
        if (_page == 1) _hasMore = res.hasMore;
        _error = null;
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
    }
  }

  Widget _body() {
    final error = _error;
    if (_loading && _items.isEmpty) {
      return const SkeletonList(count: 6, itemHeight: 82, headerHeight: null);
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
    final searching = _search.text.trim().isNotEmpty || _openOnly;
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                StateView(
                  icon: searching
                      ? Icons.search_off_rounded
                      : Icons.forum_outlined,
                  title: searching ? 'No chats found' : 'No chats yet',
                  text: searching
                      ? 'Try a different name or number.'
                      : 'When a customer messages your WhatsApp number, the chat shows up here.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= _items.length) {
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
                final c = _items[i];
                return FadeIn(
                  delay: i < 8 ? i * 30 : 0,
                  child: _ChatTile(conversation: c, onTap: () => _open(c)),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
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
      body: Column(
        children: [
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
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
                              tooltip: 'Clear',
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
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('Open'),
                  selected: _openOnly,
                  onSelected: (v) {
                    _openOnly = v;
                    _restart();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.conversation, required this.onTap});

  final WaConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unread > 0;
    final initial = c.contact.title.trim().isEmpty
        ? '?'
        : c.contact.title.trim()[0].toUpperCase();
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: brand.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: brand,
                    ),
                  ),
                ),
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
                      Expanded(
                        child: Text(
                          c.preview.isEmpty ? 'No messages yet' : c.preview,
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
    );
  }
}
