import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gbp_models.dart';
import '../services/api_service.dart';
import '../services/gbp_service.dart';
import '../services/location_store.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
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
    if (mounted && _data == null) setState(() => _loading = true);
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
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setDays(int days) {
    if (days == _days) return;
    setState(() {
      _days = days;
      _loading = true;
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyException(e).message)),
        );
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
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading && data == null
            ? const Center(child: CircularProgressIndicator())
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
                    onSelectionChanged: (s) => _setDays(s.first),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null && data == null)
                    _Message(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load insights',
                      text: _error!,
                      action: FilledButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    )
                  else if (data != null && !data.connected)
                    _Message(
                      icon: Icons.link_off_rounded,
                      title: 'Google is not connected',
                      text: data.message.isNotEmpty
                          ? data.message
                          : 'Connect your Google Business Profile to see live performance.',
                      action: FilledButton(
                        onPressed: () => widget.onNavigate(kPageOverview),
                        child: const Text('Go to Overview'),
                      ),
                    )
                  else if (data != null) ...[
                    if ((data.locationName ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 16, color: brand),
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
                    FadeIn(child: _Metrics(data: data)),
                    const SizedBox(height: 16),
                    FadeIn(delay: 120, child: _Trend(series: data.series)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_rounded, size: 18),
                      label: Text(_exporting ? 'Preparing file...' : 'Export CSV'),
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
      mainAxisExtent: 112,
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
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
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

class _Trend extends StatelessWidget {
  const _Trend({required this.series});

  final List<DailyPoint> series;

  @override
  Widget build(BuildContext context) {
    final points = series.length > 60 ? series.sublist(series.length - 60) : series;
    final maxV = points.fold<int>(0, (m, p) => p.value > m ? p.value : m);

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
          Text(
            points.isEmpty
                ? 'No data for this range'
                : 'Calls, website clicks and directions. Peak: ${_compact(maxV)} in a day',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: points.isEmpty
                ? const SizedBox.shrink()
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, progress, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _BarPainter(
                        points: points,
                        maxValue: maxV,
                        progress: progress,
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
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                ),
                const Spacer(),
                Text(
                  points.last.date,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                ),
              ],
            ),
          ],
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
  });

  final List<DailyPoint> points;
  final int maxValue;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || maxValue <= 0) return;
    final slot = size.width / points.length;
    final barWidth = (slot * 0.66).clamp(2.0, 18.0);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [brandDeep, brand],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var i = 0; i < points.length; i++) {
      final h = (points[i].value / maxValue) * size.height * progress;
      final x = i * slot + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.progress != progress || old.points != points || old.maxValue != maxValue;
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 44, color: muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 16),
          action,
        ],
      ),
    );
  }
}
