import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/location_store.dart';
import '../theme/brand.dart';
import '../widgets/count_up.dart';
import '../widgets/fade_in.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/text_scale.dart';
import 'pages.dart';

/// Google performance for the selected location: views, calls, website
/// clicks and direction requests, with a daily trend and CSV export.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  InsightsData? _data;
  int _days = 30;
  bool _loading = true;
  bool _exporting = false;
  bool _reloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    LocationStore.selectedId.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    LocationStore.selectedId.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        // First load shows the skeleton; later loads (another range or
        // location) keep what is on screen, dimmed, with a progress bar.
        if (_data == null) {
          _loading = true;
        } else {
          _reloading = true;
        }
      });
    }
    try {
      final data = await GbpService.insights(
        days: _days,
        locationId: LocationStore.selectedId.value,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = friendlyException(e).message;
      if (_data == null) {
        setState(() => _error = message);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _reloading = false;
        });
      }
    }
  }

  void _setDays(int days) {
    if (days == _days) return;
    HapticFeedback.selectionClick();
    setState(() => _days = days);
    _load();
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await GbpService.insightsCsv(
        days: _days,
        locationId: LocationStore.selectedId.value,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/eydia_insights_${_days}d.csv');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Eydia insights, last $_days days',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyException(e).message)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          if (_reloading) const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _reloading ? 0.55 : 1,
              child: RefreshIndicator(
                color: brand,
                onRefresh: _load,
                child: _loading && data == null
                    ? const _InsightsSkeleton()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 7, label: Text('7 days')),
                              ButtonSegment(value: 30, label: Text('30 days')),
                              ButtonSegment(value: 90, label: Text('90 days')),
                            ],
                            selected: {_days},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) => _setDays(s.first),
                            style: SegmentedButton.styleFrom(
                              backgroundColor: Colors.white,
                              selectedBackgroundColor: brand.withValues(
                                alpha: 0.14,
                              ),
                              selectedForegroundColor: brand,
                              foregroundColor: muted,
                              side: const BorderSide(color: Color(0xFFE3E8F2)),
                              textStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_error != null && data == null)
                            StateView.error(
                              title: 'Could not load insights',
                              text: _error!,
                              onRetry: _load,
                            )
                          else if (data != null && !data.connected)
                            StateView(
                              icon: Icons.link_off_rounded,
                              title: 'Google is not connected',
                              text: data.message.isNotEmpty
                                  ? data.message
                                  : 'Connect your Google Business Profile to see live performance.',
                              actionLabel: 'Go to Overview',
                              onAction: () => widget.onNavigate(kPageOverview),
                            )
                          else if (data != null) ...[
                            if ((data.locationName ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.place_rounded,
                                      size: 16,
                                      color: brand,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        data.locationName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            FadeIn(
                              child: _ActionsHero(data: data, days: _days),
                            ),
                            const SizedBox(height: 14),
                            FadeIn(delay: 60, child: _Metrics(data: data)),
                            const SizedBox(height: 16),
                            FadeIn(
                              delay: 120,
                              child: _Trend(series: data.series),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _exporting ? null : _export,
                              icon: _exporting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.file_download_rounded,
                                      size: 18,
                                    ),
                              label: Text(
                                _exporting ? 'Preparing file...' : 'Export CSV',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _compact(num v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.round().toString();
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data});

  final InsightsData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.visibility_rounded, 'Total views', data.impressions, brand),
      (Icons.call_rounded, 'Calls', data.calls, good),
      (Icons.language_rounded, 'Website clicks', data.websiteClicks, brandDeep),
      (Icons.directions_rounded, 'Directions', data.directions, warn),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: textScaled(context, 112),
      children: [
        for (final (icon, label, value, color) in items)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value.toDouble()),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Text(
                      _compact(v),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Daily bar chart. Touch or drag across it to read the exact day and number,
/// with the best day and the daily average underneath.
class _Trend extends StatefulWidget {
  const _Trend({required this.series});

  final List<DailyPoint> series;

  @override
  State<_Trend> createState() => _TrendState();
}

class _TrendState extends State<_Trend> {
  int? _selected;

  List<DailyPoint> get _points => widget.series.length > 60
      ? widget.series.sublist(widget.series.length - 60)
      : widget.series;

  @override
  void didUpdateWidget(covariant _Trend old) {
    super.didUpdateWidget(old);
    // A new range or location: the old bar index means nothing now.
    if (old.series != widget.series) _selected = null;
  }

  void _pick(double dx, double width) {
    final points = _points;
    if (points.isEmpty || width <= 0) return;
    final i = (dx / width * points.length).floor().clamp(0, points.length - 1);
    if (i != _selected) {
      HapticFeedback.selectionClick();
      setState(() => _selected = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final maxV = points.fold<int>(0, (m, p) => p.value > m ? p.value : m);
    final total = points.fold<int>(0, (s, p) => s + p.value);
    final average = points.isEmpty ? 0.0 : total / points.length;
    DailyPoint? best;
    for (final p in points) {
      if (best == null || p.value > best.value) best = p;
    }
    final sel = _selected != null && _selected! < points.length
        ? points[_selected!]
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily interactions',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          // The line under the title becomes the reading for the touched day.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              points.isEmpty
                  ? 'No data for this range'
                  : sel != null
                  ? '${sel.date}: ${sel.value} ${sel.value == 1 ? 'interaction' : 'interactions'}'
                  : 'Calls, website clicks and directions. Touch a bar to see a day.',
              key: ValueKey(sel?.date ?? 'hint'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: sel != null ? FontWeight.w800 : FontWeight.w400,
                color: sel != null ? brand : muted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: points.isEmpty
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, box) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _pick(d.localPosition.dx, box.maxWidth),
                      onHorizontalDragStart: (d) =>
                          _pick(d.localPosition.dx, box.maxWidth),
                      onHorizontalDragUpdate: (d) =>
                          _pick(d.localPosition.dx, box.maxWidth),
                      child: Semantics(
                        label:
                            'Bar chart of daily interactions. '
                            'Best day ${best?.date ?? ''} with ${best?.value ?? 0}. '
                            'Average ${average.toStringAsFixed(1)} per day.',
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, progress, _) => CustomPaint(
                            size: Size.infinite,
                            painter: _BarPainter(
                              points: points,
                              maxValue: maxV,
                              progress: progress,
                              selected: _selected,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  points.first.date,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: muted,
                  ),
                ),
                const Spacer(),
                Text(
                  points.last.date,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: muted,
                  ),
                ),
              ],
            ),
            if (total > 0 && best != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Best day',
                      value: '${_compact(best.value)}  ·  ${best.date}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      label: 'Daily average',
                      value: average.toStringAsFixed(average >= 10 ? 0 : 1),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.points,
    required this.maxValue,
    required this.progress,
    required this.selected,
  });

  final List<DailyPoint> points;
  final int maxValue;
  final double progress;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || maxValue <= 0) return;
    final grid = Paint()
      ..color = const Color(0xFFEEF1F7)
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = (size.height - 0.5) * (1 - f);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final slot = size.width / points.length;
    final barWidth = (slot * 0.66).clamp(2.0, 18.0);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [brandDeep, brand],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    // With a bar picked, the others step back.
    final dim = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          brandDeep.withValues(alpha: 0.35),
          brand.withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var i = 0; i < points.length; i++) {
      final h = (points[i].value / maxValue) * size.height * progress;
      final x = i * slot + (slot - barWidth) / 2;
      final isPicked = selected == i;
      if (isPicked) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(i * slot, 0, slot, size.height),
            const Radius.circular(4),
          ),
          Paint()..color = brand.withValues(alpha: 0.08),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(4),
        ),
        selected == null || isPicked ? paint : dim,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.progress != progress ||
      old.points != points ||
      old.maxValue != maxValue ||
      old.selected != selected;
}

/// What customers did after finding you: one total, split by action type.
class _ActionsHero extends StatelessWidget {
  const _ActionsHero({required this.data, required this.days});

  final InsightsData data;
  final int days;

  @override
  Widget build(BuildContext context) {
    final parts = [
      ('Calls', data.calls, good),
      ('Website', data.websiteClicks, brandDeep),
      ('Directions', data.directions, warn),
    ];
    final total = parts.fold<int>(0, (s, p) => s + p.$2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [royalNavy, royalIndigo, royalViolet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: royalNavy.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer actions, last $days days',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUp(
              value: total,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: total == 0
                  ? const ColoredBox(color: Colors.white24)
                  : Row(
                      children: [
                        for (final p in parts)
                          if (p.$2 > 0)
                            Expanded(
                              flex: p.$2,
                              child: ColoredBox(color: p.$3),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final p in parts)
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: p.$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          total == 0
                              ? p.$1
                              : '${p.$1} ${(p.$2 * 100 / total).round()}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      builder: (context, o) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          SkeletonBox(opacity: o, height: 40, radius: 20),
          const SizedBox(height: 16),
          SkeletonBox(opacity: o, height: 140, radius: 24),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBox(opacity: o, height: 112, radius: 20)),
              const SizedBox(width: 12),
              Expanded(child: SkeletonBox(opacity: o, height: 112, radius: 20)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(opacity: o, height: 112, radius: 20)),
              const SizedBox(width: 12),
              Expanded(child: SkeletonBox(opacity: o, height: 112, radius: 20)),
            ],
          ),
          const SizedBox(height: 16),
          SkeletonBox(opacity: o, height: 250, radius: 22),
        ],
      ),
    );
  }
}
