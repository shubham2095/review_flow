import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seo_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/seo_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/tab_label.dart';
import '../widgets/wa_ui.dart';
import 'seo_sheets.dart';

/// Said before anything that uses AI credits. The cost itself is set by the
/// server, so the app does not quote a number.
const seoCreditNote = 'This uses AI credits from your plan.';

/// "Local SEO": the phrases you track, the competitors you compare with, and
/// AI keyword ideas. A page of the home shell (no app bar of its own).
class SeoScreen extends StatefulWidget {
  const SeoScreen({super.key});

  @override
  State<SeoScreen> createState() => _SeoScreenState();
}

class _SeoScreenState extends State<SeoScreen> {
  SeoOverview? _overview;
  List<SeoKeyword> _keywords = [];
  List<SeoCompetitor> _competitors = [];
  int _tab = 0;
  bool _loading = true;
  Object? _error;

  /// The keyword or competitor an AI call is running for.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SeoService.overview(),
        SeoService.keywords(),
        SeoService.competitors(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as SeoOverview;
        _keywords = results[1] as List<SeoKeyword>;
        _competitors = results[2] as List<SeoCompetitor>;
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

  Future<void> _sheet(Widget sheet) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => sheet,
    );
    if (message == null || !mounted) return;
    showToast(context, message);
    _load();
  }

  Future<void> _show(Widget sheet) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => sheet,
  );

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
    bool danger = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: bad) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  SeoContext? get _context => _overview?.context;
  List<SeoPlace> get _places => _overview?.locations ?? const [];

  void _addKeyword({String keyword = '', String? city}) => _sheet(
    SeoKeywordSheet(
      places: _places,
      initialKeyword: keyword,
      initialCity: city ?? _context?.city ?? '',
      initialPlaceId: _context?.locationId,
    ),
  );

  Future<void> _check(SeoKeyword k) async {
    if (_busyId != null) return;
    if (!await _confirm(
      title: 'Check rank for "${k.keyword}"?',
      text: '$seoCreditNote It gives an AI estimate, not a measured position.',
      action: 'Check',
    )) {
      return;
    }
    setState(() => _busyId = k.id);
    try {
      final (fresh, result) = await SeoService.checkKeyword(k.id);
      if (!mounted) return;
      setState(() {
        _keywords = [for (final x in _keywords) x.id == k.id ? fresh : x];
      });
      await _show(SeoRankResultSheet(keyword: fresh, result: result));
      if (mounted) _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteKeyword(SeoKeyword k) async {
    if (!await _confirm(
      title: 'Stop tracking "${k.keyword}"?',
      text: 'Its rank history is removed too.',
      action: 'Remove',
      danger: true,
    )) {
      return;
    }
    try {
      await SeoService.deleteKeyword(k.id);
      if (!mounted) return;
      showToast(context, 'Keyword removed.');
      _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    }
  }

  Future<void> _analyze(SeoCompetitor c) async {
    if (_busyId != null) return;
    if (!await _confirm(
      title: 'Analyze ${c.name}?',
      text: '$seoCreditNote It compares them with your own reviews.',
      action: 'Analyze',
    )) {
      return;
    }
    setState(() => _busyId = c.id);
    try {
      final (fresh, analysis) = await SeoService.analyze(c.id);
      if (!mounted) return;
      setState(() {
        _competitors = [for (final x in _competitors) x.id == c.id ? fresh : x];
      });
      await _show(SeoAnalysisSheet(competitor: fresh, analysis: analysis));
      if (mounted) _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteCompetitor(SeoCompetitor c) async {
    if (!await _confirm(
      title: 'Remove ${c.name}?',
      text: 'They are no longer compared with you.',
      action: 'Remove',
      danger: true,
    )) {
      return;
    }
    try {
      await SeoService.deleteCompetitor(c.id);
      if (!mounted) return;
      showToast(context, 'Competitor removed.');
      _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    }
  }

  // ---- Tabs ----

  Widget _overviewTab(SeoOverview o) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Keywords',
                value: o.keywords,
                icon: Icons.manage_search_rounded,
                onTap: () => setState(() => _tab = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Competitors',
                value: o.competitors,
                icon: Icons.groups_rounded,
                onTap: () => setState(() => _tab = 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StatTile(
          label: 'Rank checks this month',
          value: o.checksThisMonth,
          icon: Icons.query_stats_rounded,
        ),
        if (!o.aiConfigured)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: warn.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'AI is not set up on the server yet, so rank checks and '
                'analyses give general advice only.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: ink,
                  height: 1.4,
                ),
              ),
            ),
          ),
        const SectionTitle(
          'Keyword ideas',
          padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
        ),
        _IdeasCard(
          context: o.context,
          onUse: (keyword, city) => _addKeyword(keyword: keyword, city: city),
        ),
      ],
    );
  }

  Widget _keywordsTab() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _keywords.isEmpty ? 2 : _keywords.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_keywords.length} tracked',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _addKeyword(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add keyword'),
                ),
              ],
            ),
          );
        }
        if (_keywords.isEmpty) {
          return const StateView(
            icon: Icons.manage_search_rounded,
            title: 'No keywords yet',
            text:
                'Add the phrases customers search for, then check where you '
                'show up. The Overview tab can suggest ideas.',
          );
        }
        final k = _keywords[i - 1];
        return _KeywordCard(
          keyword: k,
          busy: _busyId == k.id,
          disabled: _busyId != null,
          onCheck: () => _check(k),
          onHistory: () => _show(SeoHistorySheet(keyword: k)),
          onDelete: () => _deleteKeyword(k),
        );
      },
    );
  }

  Widget _competitorsTab() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _competitors.isEmpty ? 2 : _competitors.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_competitors.length} '
                    '${_competitors.length == 1 ? 'competitor' : 'competitors'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _sheet(
                    SeoCompetitorSheet(
                      places: _places,
                      initialCity: _context?.city ?? '',
                      initialPlaceId: _context?.locationId,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add competitor'),
                ),
              ],
            ),
          );
        }
        if (_competitors.isEmpty) {
          return const StateView(
            icon: Icons.groups_outlined,
            title: 'No competitors yet',
            text:
                'Add a business near you and the AI compares them with your '
                'reviews and profile.',
          );
        }
        final c = _competitors[i - 1];
        return _CompetitorCard(
          competitor: c,
          busy: _busyId == c.id,
          disabled: _busyId != null,
          onAnalyze: () => _analyze(c),
          onShow: c.analysis.isEmpty ? null : () => _showLast(c),
          onDelete: () => _deleteCompetitor(c),
        );
      },
    );
  }

  /// The last saved summary, without spending credits again.
  void _showLast(SeoCompetitor c) => _show(
    SeoAnalysisSheet(
      competitor: c,
      analysis: SeoAnalysis(source: 'ai', summary: c.analysis),
    ),
  );

  Widget _content(SeoOverview o) {
    final body = switch (_tab) {
      1 => _keywordsTab(),
      2 => _competitorsTab(),
      _ => _overviewTab(o),
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: TabLabel('Overview')),
                ButtonSegment(value: 1, label: TabLabel('Keywords')),
                ButtonSegment(value: 2, label: TabLabel('Competitors')),
              ],
              selected: {_tab},
              onSelectionChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _tab = v.first);
              },
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: brand,
            onRefresh: _load,
            child: ContentWidth(child: body),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 3, itemHeight: 96, headerHeight: 52);
    }
    final error = _error;
    final o = _overview;
    if (error != null && o == null) {
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
                  title: 'Could not load SEO',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    return _content(o!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

class _KeywordCard extends StatelessWidget {
  const _KeywordCard({
    required this.keyword,
    required this.busy,
    required this.disabled,
    required this.onCheck,
    required this.onHistory,
    required this.onDelete,
  });

  final SeoKeyword keyword;
  final bool busy;
  final bool disabled;
  final VoidCallback onCheck;
  final VoidCallback onHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final k = keyword;
    final (label, color, icon) = seoRankInfo(k.latestRank);
    final where = [
      if (k.city.isNotEmpty) k.city,
      if (k.locationName.isNotEmpty) k.locationName,
    ].join(' · ');
    final checked = k.lastCheckedAt == null
        ? 'Never checked'
        : 'Checked ${fmtDate(k.lastCheckedAt!)} · ${k.checks} '
              '${k.checks == 1 ? 'check' : 'checks'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  label:
                      '${k.keyword}${where.isEmpty ? '' : ', $where'}, '
                      '${k.latestRank.isEmpty ? 'not checked yet' : 'AI estimate $label'}, '
                      '$checked',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.keyword,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      if (where.isNotEmpty)
                        Text(
                          where,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InfoChip(label, icon: icon, color: color),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              checked,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More for ${k.keyword}',
                enabled: !disabled,
                onSelected: (v) {
                  if (v == 'history') onHistory();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'history', child: Text('History')),
                  PopupMenuItem(value: 'delete', child: Text('Stop tracking')),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: disabled ? null : onCheck,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_rounded, size: 18),
              label: Text(busy ? 'Checking…' : 'Check rank'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetitorCard extends StatelessWidget {
  const _CompetitorCard({
    required this.competitor,
    required this.busy,
    required this.disabled,
    required this.onAnalyze,
    required this.onShow,
    required this.onDelete,
  });

  final SeoCompetitor competitor;
  final bool busy;
  final bool disabled;
  final VoidCallback onAnalyze;
  final VoidCallback? onShow;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = competitor;
    final where = [
      if (c.city.isNotEmpty) c.city,
      if (c.locationName.isNotEmpty) 'vs ${c.locationName}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    if (where.isNotEmpty)
                      Text(
                        where,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More for ${c.name}',
                enabled: !disabled,
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              ),
            ],
          ),
          if (c.analysis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Text(
                c.analysis,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: inkSoft,
                  height: 1.4,
                ),
              ),
            ),
          if (c.lastAnalyzedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Analyzed ${fmtDate(c.lastAnalyzedAt!)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: muted,
                ),
              ),
            ),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: disabled ? null : onAnalyze,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(busy ? 'Analyzing…' : 'Analyze'),
              ),
              if (onShow != null)
                TextButton(
                  onPressed: disabled ? null : onShow,
                  child: const Text('Last result'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks the AI for keyword ideas and lets you tap one to start tracking it.
class _IdeasCard extends StatefulWidget {
  const _IdeasCard({required this.context, required this.onUse});

  final SeoContext? context;
  final void Function(String keyword, String city) onUse;

  @override
  State<_IdeasCard> createState() => _IdeasCardState();
}

class _IdeasCardState extends State<_IdeasCard> {
  late final _business = TextEditingController(
    text: widget.context?.business ?? '',
  );
  late final _city = TextEditingController(text: widget.context?.city ?? '');
  late final _industry = TextEditingController(
    text: widget.context?.industry ?? '',
  );
  List<SeoIdeaGroup> _groups = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _business.dispose();
    _city.dispose();
    _industry.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_business.text.trim().isEmpty || _city.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _error = 'Write your business name and city.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Get keyword ideas?'),
        content: const Text(seoCreditNote),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Get ideas'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final groups = await SeoService.ideas(
        business: _business.text.trim(),
        city: _city.text.trim(),
        industry: _industry.text.trim(),
      );
      if (mounted) setState(() => _groups = groups);
    } catch (e) {
      if (mounted) setState(() => _error = errorLine(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _business,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: waInputDecoration('Business', onWhite: false),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _city,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: waInputDecoration('City', onWhite: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _industry,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: waInputDecoration(
                    'Industry (optional)',
                    onWhite: false,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lightbulb_rounded, size: 18),
            label: Text(_busy ? 'Thinking…' : 'Get ideas'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: GoogleFonts.plusJakartaSans(color: bad, fontSize: 12.5),
              ),
            ),
          for (final g in _groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Semantics(
                header: true,
                child: Text(
                  g.theme,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: ink,
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final k in g.keywords)
                  ActionChip(
                    label: Text(k),
                    tooltip: 'Track "$k"',
                    onPressed: () => widget.onUse(k, _city.text.trim()),
                  ),
              ],
            ),
          ],
          if (_groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Tap an idea to start tracking it.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
