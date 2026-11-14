import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/offline_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import 'whatsapp_blacklist_screen.dart';
import 'whatsapp_contact_sheet.dart';
import 'whatsapp_inbox_screen.dart' show shortWhen;

enum _Filter { all, hot, blocked, optedOut }

/// Contacts: search, quick filters (all, hot, blocked, opted out), add, and a
/// detail sheet to edit, block or delete. Blocked numbers have their own page.
class WhatsAppContactsScreen extends StatefulWidget {
  const WhatsAppContactsScreen({super.key});

  @override
  State<WhatsAppContactsScreen> createState() => _WhatsAppContactsScreenState();
}

class _WhatsAppContactsScreenState extends State<WhatsAppContactsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<WaContactRecord> _items = [];
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  _Filter _filter = _Filter.all;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<WaContactPage> _fetch(int page) => WhatsAppService.contacts(
    search: _search.text.trim(),
    hot: _filter == _Filter.hot,
    blocked: _filter == _Filter.blocked,
    optedOut: _filter == _Filter.optedOut,
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
        _total = res.total;
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openSheet(WaContactRecord? contact) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => WhatsAppContactSheet(contact: contact),
    );
    if (message == null) return;
    _snack(message);
    _load();
  }

  Future<void> _openBlocked() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const WhatsAppBlacklistScreen()),
    );
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
                  title: 'Could not load contacts',
                  text: friendlyException(error).message,
                  onRetry: _restart,
                ),
        ),
      );
    }
    final filtering = _search.text.trim().isNotEmpty || _filter != _Filter.all;
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                StateView(
                  icon: filtering
                      ? Icons.search_off_rounded
                      : Icons.contacts_outlined,
                  title: filtering ? 'No contacts found' : 'No contacts yet',
                  text: filtering
                      ? 'Try a different search or filter.'
                      : 'People who message you are added here automatically. '
                            'You can also add one with the button below.',
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
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
                  child: _ContactTile(contact: c, onTap: () => _openSheet(c)),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Filter.all: 'All',
      _Filter.hot: 'Hot',
      _Filter.blocked: 'Blocked',
      _Filter.optedOut: 'Opted out',
    };
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          _loading || _error != null ? 'Contacts' : 'Contacts ($_total)',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        actions: [
          IconButton(
            tooltip: 'Blocked numbers',
            icon: const Icon(Icons.block_rounded),
            onPressed: _openBlocked,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(null),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add contact'),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 450), _restart);
              },
              decoration: InputDecoration(
                hintText: 'Search name, number, email or tag',
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
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(labels[f]!),
                      selected: _filter == f,
                      onSelected: (_) {
                        if (_filter == f) return;
                        _filter = f;
                        _restart();
                      },
                    ),
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

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final WaContactRecord contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final initial = c.title.trim().isEmpty
        ? '?'
        : c.title.trim()[0].toUpperCase();
    final flags = <Widget>[
      if (c.isHot) _Flag('Hot', bad, Icons.local_fire_department_rounded),
      if (c.isBlocked) const _Flag('Blocked', muted, Icons.block_rounded),
      if (c.optedOut) const _Flag('Opted out', warn, Icons.unsubscribe_rounded),
    ];
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ),
                      Text(
                        shortWhen(c.lastInteractionAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  if (c.name.trim().isNotEmpty)
                    Text(
                      c.phone,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                  if (c.tags.isNotEmpty || flags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ...flags,
                        for (final t in c.tags.take(3)) _TagChip(t),
                        if (c.tags.length > 3)
                          _TagChip('+${c.tags.length - 3}'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.text, this.color, this.icon);

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: brand,
        ),
      ),
    );
  }
}
