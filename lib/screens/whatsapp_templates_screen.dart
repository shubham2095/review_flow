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
import 'whatsapp_template_create_screen.dart';
import 'whatsapp_template_sheet.dart';

/// Colour and label for a Meta template status.
({Color color, String label}) templateStatus(String status) {
  switch (status.toUpperCase()) {
    case 'APPROVED':
      return (color: good, label: 'Approved');
    case 'PENDING':
    case 'IN_APPEAL':
      return (color: warn, label: 'Pending');
    case 'REJECTED':
      return (color: bad, label: 'Rejected');
    case 'PAUSED':
    case 'DISABLED':
      return (
        color: muted,
        label: status[0] + status.substring(1).toLowerCase(),
      );
    default:
      return (
        color: muted,
        label: status.isEmpty
            ? 'Unknown'
            : status[0] + status.substring(1).toLowerCase(),
      );
  }
}

/// Templates: search, status filter, sync from Meta, create, open one to read
/// it or delete it.
class WhatsAppTemplatesScreen extends StatefulWidget {
  const WhatsAppTemplatesScreen({super.key});

  @override
  State<WhatsAppTemplatesScreen> createState() =>
      _WhatsAppTemplatesScreenState();
}

class _WhatsAppTemplatesScreenState extends State<WhatsAppTemplatesScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<WaTemplate> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _syncing = false;
  String? _status; // null = all
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

  Future<WaTemplatePage> _fetch(int page) => WhatsAppService.templates(
    search: _search.text.trim(),
    status: _status,
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    final gen = _generation;
    try {
      final res = await _fetch(_page + 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        final have = _items.map((t) => t.id).toSet();
        _items = [..._items, ...res.items.where((t) => !have.contains(t.id))];
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

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      _snack(await WhatsAppService.syncTemplates());
      await _load();
    } catch (e) {
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _open(WaTemplate t) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => WhatsAppTemplateSheet(template: t),
    );
    if (message == null) return;
    _snack(message);
    _load();
  }

  Future<void> _create() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const WhatsAppTemplateCreateScreen()),
    );
    if (message == null) return;
    _snack(message);
    _load();
  }

  Widget _body() {
    final error = _error;
    if (_loading && _items.isEmpty) {
      return const SkeletonList(count: 5, itemHeight: 82, headerHeight: null);
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
                  title: 'Could not load templates',
                  text: friendlyException(error).message,
                  onRetry: _restart,
                ),
        ),
      );
    }
    final filtering = _search.text.trim().isNotEmpty || _status != null;
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
                      : Icons.description_outlined,
                  title: filtering ? 'No templates found' : 'No templates yet',
                  text: filtering
                      ? 'Try a different search or filter.'
                      : 'Create a template, or tap the sync button to pull in the ones you already have on Meta.',
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
                final t = _items[i];
                return FadeIn(
                  delay: i < 8 ? i * 30 : 0,
                  child: _TemplateTile(template: t, onTap: () => _open(t)),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const filters = <String?, String>{
      null: 'All',
      'approved': 'Approved',
      'pending': 'Pending',
      'rejected': 'Rejected',
    };
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Templates',
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
            tooltip: 'Sync from Meta',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New template'),
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
                hintText: 'Search by template name',
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
                for (final e in filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _status == e.key,
                      onSelected: (_) {
                        if (_status == e.key) return;
                        _status = e.key;
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

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});

  final WaTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final s = templateStatus(t.status);
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: s.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (t.category.isNotEmpty)
                  t.category[0] + t.category.substring(1).toLowerCase(),
                t.language,
              ].where((x) => x.isNotEmpty).join(' · '),
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
            ),
            if (t.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                t.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: const Color(0xFF4A5468),
                  height: 1.35,
                ),
              ),
            ],
            if (t.status.toUpperCase() == 'REJECTED' &&
                t.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                t.rejectionReason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: bad),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
