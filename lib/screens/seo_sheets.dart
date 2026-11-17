import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seo_models.dart';
import '../services/access_problem.dart';
import '../services/seo_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_ui.dart';

/// A rank as a word, a colour and an icon. The rank is an AI estimate
/// ("Top 3", "4-10", "Not in top 10"), never a measured position.
(String, Color, IconData) seoRankInfo(String rank) {
  final r = rank.trim().toLowerCase();
  if (r.isEmpty) {
    return ('Not checked yet', muted, Icons.help_outline_rounded);
  }
  if (r.contains('not in')) {
    return (rank.trim(), bad, Icons.trending_down_rounded);
  }
  if (r.contains('top 3') || r.contains('top3')) {
    return (rank.trim(), good, Icons.emoji_events_rounded);
  }
  if (r.contains('4')) {
    return (rank.trim(), warn, Icons.trending_flat_rounded);
  }
  return (rank.trim(), muted, Icons.help_outline_rounded);
}

/// What is wrong with a keyword form, or null.
String? seoKeywordProblem(String keyword) {
  final k = keyword.trim();
  if (k.isEmpty) return 'Write the search phrase to track.';
  if (k.length > 120) return 'Keep the phrase under 120 characters.';
  return null;
}

/// What is wrong with a competitor form, or null.
String? seoCompetitorProblem(String name) =>
    name.trim().isEmpty ? 'Write the competitor\'s name.' : null;

Widget _bullets(String heading, List<String> items, {Color color = ink}) {
  if (items.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            heading,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: TextStyle(color: color)),
                Expanded(
                  child: Text(
                    t,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: inkSoft,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Said above an AI result so nobody takes it for a measured fact.
const seoEstimateNote =
    'This is an AI estimate of where you show on Google for this phrase, not '
    'a measured position.';

/// Adds a keyword to track. Pops with a message when saved.
class SeoKeywordSheet extends StatefulWidget {
  const SeoKeywordSheet({
    super.key,
    this.places = const [],
    this.initialKeyword = '',
    this.initialCity = '',
    this.initialPlaceId,
  });

  final List<SeoPlace> places;
  final String initialKeyword;
  final String initialCity;
  final String? initialPlaceId;

  @override
  State<SeoKeywordSheet> createState() => _SeoKeywordSheetState();
}

class _SeoKeywordSheetState extends State<SeoKeywordSheet> {
  late final _keyword = TextEditingController(text: widget.initialKeyword);
  late final _city = TextEditingController(text: widget.initialCity);
  late String? _place = widget.places.any((p) => p.id == widget.initialPlaceId)
      ? widget.initialPlaceId
      : null;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _keyword.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = seoKeywordProblem(_keyword.text);
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await SeoService.addKeyword(
        keyword: _keyword.text.trim(),
        city: _city.text.trim(),
        locationId: _place,
      );
      if (mounted) Navigator.of(context).pop('Keyword added.');
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _busy = false;
        _notice = errorLine(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Track a keyword',
      subtitle:
          'The phrase customers type into Google, such as "dentist in Pune".',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _keyword,
            enabled: !_busy,
            maxLength: 120,
            decoration: waInputDecoration('Keyword', hint: 'dentist near me'),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _city,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: waInputDecoration('City (optional)', hint: 'Pune'),
          ),
          if (widget.places.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _place,
              isExpanded: true,
              decoration: waInputDecoration('Business location (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any')),
                for (final p in widget.places)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _place = v),
            ),
          ],
          const SizedBox(height: 14),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? Semantics(
                    label: 'Saving',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Text('Add keyword'),
          ),
        ],
      ),
    );
  }
}

/// Adds a competitor to compare with. Pops with a message when saved.
class SeoCompetitorSheet extends StatefulWidget {
  const SeoCompetitorSheet({
    super.key,
    this.places = const [],
    this.initialCity = '',
    this.initialPlaceId,
  });

  final List<SeoPlace> places;
  final String initialCity;
  final String? initialPlaceId;

  @override
  State<SeoCompetitorSheet> createState() => _SeoCompetitorSheetState();
}

class _SeoCompetitorSheetState extends State<SeoCompetitorSheet> {
  final _name = TextEditingController();
  late final _city = TextEditingController(text: widget.initialCity);
  late String? _place = widget.places.any((p) => p.id == widget.initialPlaceId)
      ? widget.initialPlaceId
      : null;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = seoCompetitorProblem(_name.text);
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await SeoService.addCompetitor(
        name: _name.text.trim(),
        city: _city.text.trim(),
        locationId: _place,
      );
      if (mounted) Navigator.of(context).pop('Competitor added.');
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _busy = false;
        _notice = errorLine(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Add a competitor',
      subtitle: 'A business near you that customers might choose instead.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: waInputDecoration('Business name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: waInputDecoration('City (optional)'),
          ),
          if (widget.places.length > 1) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _place,
              isExpanded: true,
              decoration: waInputDecoration('Compare with my location'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final p in widget.places)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _place = v),
            ),
          ],
          const SizedBox(height: 14),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? Semantics(
                    label: 'Saving',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Text('Add competitor'),
          ),
        ],
      ),
    );
  }
}

/// Past rank checks for one keyword, newest first.
class SeoHistorySheet extends StatefulWidget {
  const SeoHistorySheet({super.key, required this.keyword});

  final SeoKeyword keyword;

  @override
  State<SeoHistorySheet> createState() => _SeoHistorySheetState();
}

class _SeoHistorySheetState extends State<SeoHistorySheet> {
  List<SeoSnapshot> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await SeoService.history(widget.keyword.id);
      if (!mounted) return;
      setState(() {
        _items = items.reversed.toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorLine(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: widget.keyword.keyword,
      subtitle: 'Rank checks over time. $seoEstimateNote',
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null
          ? SheetNotice(_error)
          : _items.isEmpty
          ? Text(
              'No checks yet. Run "Check rank" to start the history.',
              style: GoogleFonts.plusJakartaSans(color: muted),
            )
          : Column(
              children: [for (final s in _items) _HistoryRow(snapshot: s)],
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.snapshot});

  final SeoSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final (label, color, icon) = seoRankInfo(s.rank);
    final when = s.checkedAt == null ? '' : fmtDateTime(s.checkedAt!);
    return Semantics(
      container: true,
      label: [
        when,
        if (s.rank.isEmpty) 'No estimate' else label,
        s.summary,
      ].where((t) => t.isNotEmpty).join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.rank.isEmpty ? 'No estimate' : label,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: s.rank.isEmpty ? muted : color,
                      ),
                    ),
                    if (when.isNotEmpty)
                      Text(
                        when,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: muted,
                        ),
                      ),
                    if (s.summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          s.summary,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: inkSoft,
                            height: 1.4,
                          ),
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

/// The outcome of "Check rank".
class SeoRankResultSheet extends StatelessWidget {
  const SeoRankResultSheet({
    super.key,
    required this.keyword,
    required this.result,
  });

  final SeoKeyword keyword;
  final SeoRankResult result;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = seoRankInfo(result.rank);
    return AppSheet(
      title: keyword.keyword,
      subtitle: result.isAi
          ? seoEstimateNote
          : 'AI is not set up on the server, so this is general advice, not '
                'an estimate for your business.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.rank.isNotEmpty)
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: color,
                  ),
                ),
              ],
            ),
          if (result.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                result.summary,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: inkSoft,
                  height: 1.45,
                ),
              ),
            ),
          _bullets('What to do next', result.tips, color: brand),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// The outcome of "Analyze" for a competitor.
class SeoAnalysisSheet extends StatelessWidget {
  const SeoAnalysisSheet({
    super.key,
    required this.competitor,
    required this.analysis,
  });

  final SeoCompetitor competitor;
  final SeoAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    return AppSheet(
      title: competitor.name,
      subtitle: a.isAi
          ? 'An AI comparison with your own review numbers.'
          : 'AI is not set up on the server, so this is general advice.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a.myName.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoChip(a.myName, icon: Icons.storefront_rounded),
                InfoChip(
                  '${a.myAverage.toStringAsFixed(1)}/5 from ${a.myReviews} reviews',
                  icon: Icons.star_rounded,
                  color: warn,
                ),
              ],
            ),
          if (a.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                a.summary,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: inkSoft,
                  height: 1.45,
                ),
              ),
            ),
          _bullets('Your strengths', a.strengths, color: good),
          _bullets('Gaps to close', a.gaps, color: warn),
          _bullets('What to do next', a.actions, color: brand),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
