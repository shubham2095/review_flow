import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/text_scale.dart';
import '../widgets/fade_in.dart';
import '../widgets/offline_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';
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

  /// How many templates there are per status. Only known when every template
  /// is loaded (no filter, no search, no more pages): the server does not send
  /// totals per status. Null hides the numbers on the chips.
  Map<String, int>? _counts;

  void _updateCounts() {
    if (_status != null || _search.text.trim().isNotEmpty) return;
    if (_hasMore) {
      _counts = null;
      return;
    }
    var approved = 0;
    var pending = 0;
    var rejected = 0;
    for (final t in _items) {
      switch (t.status.toUpperCase()) {
        case 'APPROVED':
          approved++;
        case 'PENDING' || 'IN_APPEAL':
          pending++;
        case 'REJECTED':
          rejected++;
      }
    }
    _counts = {
      'all': _items.length,
      'approved': approved,
      'pending': pending,
      'rejected': rejected,
    };
  }

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
        _updateCounts();
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
        _updateCounts();
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
    showToast(context, text);
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      _snack(await WhatsAppService.syncTemplates());
      _counts = null;
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
    _counts = null;
    _load();
  }

  Future<void> _create() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const WhatsAppTemplateCreateScreen()),
    );
    if (message == null) return;
    _snack(message);
    _counts = null;
    _load();
  }

  Widget _body() {
    final error = _error;
    if (_loading && _items.isEmpty) {
      return const SkeletonList(count: 5, itemHeight: 96, headerHeight: null);
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
                      : 'Create a template, or sync to pull in the ones you already have on Meta.',
                  // Right where the person is looking: the sync button in the
                  // top bar is easy to miss.
                  actionLabel: filtering
                      ? null
                      : (_syncing ? 'Syncing…' : 'Sync from Meta'),
                  onAction: filtering || _syncing ? null : _sync,
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
    final counts = _counts;
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
      body: ContentWidth(
        child: Column(
          children: [
            const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 450),
                    _restart,
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Search by template name',
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
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: textScaled(context, 48),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: [
                  for (final e in filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          counts == null
                              ? e.value
                              : '${e.value} (${counts[e.key ?? 'all'] ?? 0})',
                        ),
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
    final category = t.category.isEmpty
        ? ''
        : t.category[0] + t.category.substring(1).toLowerCase();
    final media = t.headerFormat.isNotEmpty && t.headerFormat != 'TEXT';
    final rejected =
        t.status.toUpperCase() == 'REJECTED' && t.rejectionReason.isNotEmpty;
    return Pressable(
      onTap: onTap,
      child: Semantics(
        label:
            '${t.name}, ${s.label}'
            '${category.isEmpty ? '' : ', $category'}, ${t.language}'
            '${t.body.isEmpty ? '' : ': ${t.body}'}'
            '${rejected ? '. Rejected: ${t.rejectionReason}' : ''}',
        excludeSemantics: true,
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
                  StatusBadge(s.label, s.color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (category.isNotEmpty) category,
                  t.language,
                ].where((x) => x.isNotEmpty).join(' · '),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: muted,
                ),
              ),
              if (t.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  t.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: inkSoft,
                    height: 1.35,
                  ),
                ),
              ],
              if (media || t.buttons.isNotEmpty || t.needsInput) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (media)
                      InfoChip(
                        '${t.headerFormat[0]}${t.headerFormat.substring(1).toLowerCase()} header',
                        icon: Icons.photo_outlined,
                      ),
                    if (t.buttons.isNotEmpty)
                      InfoChip(
                        t.buttons.length == 1
                            ? '1 button'
                            : '${t.buttons.length} buttons',
                        icon: Icons.touch_app_outlined,
                      ),
                    if (t.needsInput && t.bodyVariables.isNotEmpty)
                      InfoChip(
                        t.bodyVariables.length == 1
                            ? '1 field'
                            : '${t.bodyVariables.length} fields',
                        icon: Icons.data_object_rounded,
                      ),
                  ],
                ),
              ],
              if (rejected) ...[
                const SizedBox(height: 6),
                Text(
                  t.rejectionReason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: bad,
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
