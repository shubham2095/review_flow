import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/insights_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const _rangeOptions = {7: '7 days', 30: '30 days', 90: '90 days', 180: '6 months'};

  int _days = 30;
  int? _locationId;
  InsightsData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final end = DateTime.now();
    final start = end.subtract(Duration(days: _days));
    final query = StringBuffer('start=${_fmt(start)}&end=${_fmt(end)}');
    if (_locationId != null) query.write('&location=$_locationId');

    try {
      final json = await ApiService.instance
          .get('/insights?$query')
          .timeout(const Duration(seconds: 45));
      if (!mounted) return;
      setState(() {
        _data = InsightsData.fromJson(json);
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setDays(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _load();
  }

  void _setLocation(int? id) {
    if (id == _locationId) return;
    setState(() => _locationId = id);
    _load();
  }

  Future<void> _downloadCsv() async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: _days));
    final query = StringBuffer('start=${_fmt(start)}&end=${_fmt(end)}');
    if (_locationId != null) query.write('&location=$_locationId');

    try {
      final bytes = await ApiService.instance.getBytes('/insights/download?$query');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/insights_${_fmt(end)}.csv');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/csv')], subject: 'Insights ${_fmt(start)} to ${_fmt(end)}'),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: surface,
        body: RefreshIndicator(
          color: brand,
          onRefresh: _load,
          child: data == null
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.7,
                      child: Center(
                        child: _loading
                            ? const CircularProgressIndicator()
                            : FadeIn(child: _ErrorBox(message: _error ?? 'Could not load insights', onRetry: _load)),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    FadeIn(
                      child: _Filters(
                        days: _days,
                        rangeOptions: _rangeOptions,
                        onDays: _setDays,
                        locations: data.locations,
                        locationId: _locationId,
                        onLocation: _setLocation,
                      ),
                    ),
                    if (data.hasGoogle) ...[
                      const SizedBox(height: 12),
                      FadeIn(
                        delay: 60,
                        child: OutlinedButton.icon(
                          onPressed: _downloadCsv,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Download CSV'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!data.hasGoogle)
                      const FadeIn(
                        child: _InfoCard(
                          emoji: '🔌',
                          text: 'Google Business Profile is not connected. Connect it from a client\'s page under "Clients" to see insights.',
                        ),
                      )
                    else if (data.error != null)
                      FadeIn(child: _InfoCard(emoji: '⚠️', text: data.error!))
                    else ...[
                      _KpiGrid(totals: data.totals),
                      const SizedBox(height: 16),
                      FadeIn(delay: 480, child: _SplitCard(totals: data.totals)),
                      const SizedBox(height: 16),
                      FadeIn(delay: 560, child: _TrendCard(daily: data.daily)),
                      if (data.perLocation.length > 1) ...[
                        const _SectionTitle('📍 By location'),
                        for (var i = 0; i < data.perLocation.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: FadeIn(
                              delay: 640 + (i < 10 ? i * 60 : 0),
                              child: _LocationRow(loc: data.perLocation[i]),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.days,
    required this.rangeOptions,
    required this.onDays,
    required this.locations,
    required this.locationId,
    required this.onLocation,
  });

  final int days;
  final Map<int, String> rangeOptions;
  final ValueChanged<int> onDays;
  final List<InsightLocation> locations;
  final int? locationId;
  final ValueChanged<int?> onLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: [
            for (final e in rangeOptions.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {days},
          onSelectionChanged: (s) => onDays(s.first),
        ),
        if (locations.length > 1) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: locationId,
            decoration: InputDecoration(
              labelText: 'Location',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All locations')),
              for (final l in locations) DropdownMenuItem<int?>(value: l.id, child: Text(l.title)),
            ],
            onChanged: onLocation,
          ),
        ],
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.totals});

  final Map<String, double> totals;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Kpi('🔎', 'Search views', sumKeys(totals, searchKeys), brand),
      _Kpi('🗺️', 'Maps views', sumKeys(totals, mapsKeys), brandDeep),
      _Kpi('📞', 'Calls', sumKeys(totals, callKeys), good),
      _Kpi('🧭', 'Directions', sumKeys(totals, directionKeys), star),
      _Kpi('🌐', 'Website clicks', sumKeys(totals, websiteKeys), warn),
      _Kpi('📅', 'Bookings', sumKeys(totals, bookingKeys), bad),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: 104,
      children: [
        for (var i = 0; i < items.length; i++)
          FadeIn(delay: i * 70, child: items[i]),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.emoji, this.label, this.value, this.color);

  final String emoji;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                child: Text(emoji, style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
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
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => Text(
                _compact(v),
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _compact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.round().toString();
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.totals});

  final Map<String, double> totals;

  @override
  Widget build(BuildContext context) {
    final search = sumKeys(totals, searchKeys);
    final maps = sumKeys(totals, mapsKeys);
    final total = search + maps;
    final searchShare = total == 0 ? 0.0 : search / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where people find you',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: searchShare),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 14,
                color: brand,
                backgroundColor: brandDeep.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Legend(color: brand, text: 'Search ${(searchShare * 100).round()}%'),
              const Spacer(),
              _Legend(color: brandDeep, text: 'Maps ${((1 - searchShare) * 100).round()}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted)),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.daily});

  final List<DailyPoint> daily;

  @override
  Widget build(BuildContext context) {
    final points = daily.length > 60 ? daily.sublist(daily.length - 60) : daily;
    final maxV = points.fold<double>(0, (m, p) => p.views > m ? p.views : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily views',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
          ),
          const SizedBox(height: 4),
          Text(
            points.isEmpty ? 'No data for this range' : 'Peak: ${_compact(maxV)} views in a day',
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
                      painter: _BarPainter(points: points, maxValue: maxV, progress: progress),
                    ),
                  ),
          ),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(points.first.date, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted)),
                const Spacer(),
                Text(points.last.date, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.points, required this.maxValue, required this.progress});

  final List<DailyPoint> points;
  final double maxValue;
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
      final h = (points[i].views / maxValue) * size.height * progress;
      final x = i * slot + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barWidth, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.progress != progress || old.points != points || old.maxValue != maxValue;
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.loc});

  final LocationInsight loc;

  @override
  Widget build(BuildContext context) {
    final views = sumKeys(loc.totals, searchKeys) + sumKeys(loc.totals, mapsKeys);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '📞 ${_compact(sumKeys(loc.totals, callKeys))}   🧭 ${_compact(sumKeys(loc.totals, directionKeys))}   🌐 ${_compact(sumKeys(loc.totals, websiteKeys))}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          Text(
            _compact(views),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: brand,
            ),
          ),
          const SizedBox(width: 4),
          Text('views', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: ink),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
