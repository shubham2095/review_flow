import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/count_up.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';
import 'whatsapp_campaigns_screen.dart' show campaignStatus;

// One colour per meaning, used the same way in the funnel, the chart and its
// legend. Every colour is also written out as text, so none carries meaning
// alone.
const _cSent = Color(0xFF9AA6C8);
const _cDelivered = brand;
const _cRead = good;
const _cFailed = bad;
const _cInbound = Color(0xFFD99A1E);

/// WhatsApp analytics: headline counts, the message funnel over 7, 30 or 90
/// days with a daily chart, and how recent campaigns performed.
class WhatsAppAnalyticsScreen extends StatefulWidget {
  const WhatsAppAnalyticsScreen({super.key});

  @override
  State<WhatsAppAnalyticsScreen> createState() =>
      _WhatsAppAnalyticsScreenState();
}

class _WhatsAppAnalyticsScreenState extends State<WhatsAppAnalyticsScreen> {
  WaDashboard? _dash;
  WaMessageStats? _stats;
  List<WaCampaignStat> _campaigns = [];
  int _days = 30;
  bool _loading = true;
  bool _loadingRange = false;
  Object? _error;
  Object? _rangeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        WhatsAppService.analyticsDashboard(),
        WhatsAppService.messageStats(_days),
        WhatsAppService.campaignStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _dash = results[0] as WaDashboard;
        _stats = results[1] as WaMessageStats;
        _campaigns = results[2] as List<WaCampaignStat>;
        _error = null;
        _rangeError = null;
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

  Future<void> _setRange(int days) async {
    if (days == _days || _loadingRange) return;
    setState(() {
      _days = days;
      _loadingRange = true;
      _rangeError = null;
    });
    try {
      final s = await WhatsAppService.messageStats(days);
      if (mounted && _days == days) setState(() => _stats = s);
    } catch (e) {
      if (mounted) setState(() => _rangeError = e);
    } finally {
      if (mounted) setState(() => _loadingRange = false);
    }
  }

  Widget _failure(Object error) {
    final access = accessProblem(error);
    if (access != null) {
      return StateView(
        icon: access.icon,
        title: access.title,
        text: access.text,
      );
    }
    return StateView.error(
      title: 'Could not load analytics',
      text: friendlyException(error).message,
      onRetry: () {
        setState(() => _loading = true);
        _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    Widget body;
    if (_loading) {
      body = const SkeletonList(count: 3, itemHeight: 140, headerHeight: 120);
    } else if (error != null && _dash == null) {
      body = Center(child: SingleChildScrollView(child: _failure(error)));
    } else {
      body = RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: _content(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Analytics',
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
          Expanded(child: body),
        ],
      ),
    );
  }

  List<Widget> _content() {
    final d = _dash!;
    final s = _stats;
    return [
      FadeIn(
        child: Row(
          children: [
            Expanded(
              child: _Tile(
                'Messages today',
                d.messagesToday,
                Icons.today_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Tile(
                'This week',
                d.messagesWeek,
                Icons.date_range_rounded,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      FadeIn(
        delay: 60,
        child: Row(
          children: [
            Expanded(
              child: _Tile(
                'This month',
                d.messagesMonth,
                Icons.calendar_month_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Tile('Contacts', d.contacts, Icons.contacts_rounded),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      FadeIn(
        delay: 120,
        child: Row(
          children: [
            Expanded(
              child: _Tile(
                'Open chats',
                d.openConversations,
                Icons.forum_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Tile(
                'Campaigns running',
                d.activeCampaigns,
                Icons.campaign_rounded,
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('Message funnel', padding: _headingPad),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 7, label: Text('7 days')),
          ButtonSegment(value: 30, label: Text('30 days')),
          ButtonSegment(value: 90, label: Text('90 days')),
        ],
        selected: {_days},
        onSelectionChanged: (v) => _setRange(v.first),
      ),
      const SizedBox(height: 12),
      if (_rangeError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            errorLine(_rangeError!),
            style: GoogleFonts.plusJakartaSans(color: bad, fontSize: 12.5),
          ),
        ),
      if (s != null)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _loadingRange ? 0.4 : 1,
          child: Column(
            children: [
              _FunnelCard(stats: s),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'Sent, delivered and read per day',
                days: s.days,
                series: [
                  ChartSeries('Sent', _cSent, (d) => d.sent),
                  ChartSeries('Delivered', _cDelivered, (d) => d.delivered),
                  ChartSeries('Read', _cRead, (d) => d.read),
                ],
              ),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'Received per day',
                days: s.days,
                series: [ChartSeries('Received', _cInbound, (d) => d.inbound)],
              ),
            ],
          ),
        ),
      const SectionTitle('Recent campaigns', padding: _headingPad),
      if (_campaigns.isEmpty)
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No campaigns yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(color: muted),
          ),
        ),
      for (final c in _campaigns) _CampaignRow(stat: c),
    ];
  }
}

const _headingPad = EdgeInsets.fromLTRB(4, 26, 4, 12);

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: brand),
            const SizedBox(height: 10),
            CountUp(
              value: value,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

String _pct(double v) =>
    v == v.roundToDouble() ? '${v.round()}%' : '${v.toStringAsFixed(1)}%';

/// One plain sentence about the funnel: "96% delivered and 41% read of 120
/// sent. 3 were not delivered. Customers sent 45 messages."
String funnelInsight(WaMessageStats s) {
  if (s.sent == 0 && s.inbound == 0) return 'No messages in this period.';
  final parts = <String>[];
  if (s.sent == 0) {
    parts.add('You sent no messages.');
  } else {
    parts.add(
      '${_pct(s.deliveryRate)} delivered and ${_pct(s.readRate)} read of '
      '${s.sent} sent.',
    );
    if (s.failed > 0) parts.add('${s.failed} not delivered.');
  }
  if (s.inbound > 0) {
    parts.add(
      'Customers sent ${s.inbound} ${s.inbound == 1 ? 'message' : 'messages'}.',
    );
  }
  return parts.join(' ');
}

/// The day with the most of the first series, as text for the chart summary.
/// Null when there is no data.
String? busiestDaySummary(List<WaDayStat> days, List<ChartSeries> series) {
  if (days.isEmpty || series.isEmpty) return null;
  var best = 0;
  var bestValue = series.first.value(days.first);
  for (var i = 1; i < days.length; i++) {
    final v = series.first.value(days[i]);
    if (v > bestValue) {
      best = i;
      bestValue = v;
    }
  }
  if (bestValue <= 0) return null;
  final d = days[best];
  return 'Busiest day ${fmtDate(d.date)}: '
      '${series.map((s) => '${s.label} ${s.value(d)}').join(', ')}';
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({required this.stats});

  final WaMessageStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final top = s.sent == 0 ? 1 : s.sent;
    Widget row(String label, int value, Color color, {String? note}) {
      final ratio = (value / top).clamp(0.0, 1.0);
      return Semantics(
        container: true,
        excludeSemantics: true,
        label: '$label ${note == null ? '$value' : '$value, $note'}',
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  Text(
                    note == null ? '$value' : '$value  ·  $note',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  color: color,
                  backgroundColor: track,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: s.sent == 0 && s.inbound == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No messages in this period.',
                  style: GoogleFonts.plusJakartaSans(color: muted),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    funnelInsight(s),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: inkSoft,
                      height: 1.4,
                    ),
                  ),
                ),
                row('Sent', s.sent, _cSent),
                row(
                  'Delivered',
                  s.delivered,
                  _cDelivered,
                  note: s.sent == 0 ? null : _pct(s.deliveryRate),
                ),
                row(
                  'Read',
                  s.read,
                  _cRead,
                  note: s.sent == 0 ? null : _pct(s.readRate),
                ),
                row('Not delivered', s.failed, _cFailed),
                row('Received from customers', s.inbound, _cInbound),
                Text(
                  'Delivered and read are shown as a share of sent. '
                  '"Not delivered" is sent minus delivered.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }
}

class ChartSeries {
  const ChartSeries(this.label, this.color, this.value);

  final String label;
  final Color color;
  final int Function(WaDayStat) value;
}

/// A bar chart with one bar per day. Several series are drawn over
/// one another from the baseline (sent behind, delivered over it, read in
/// front), which reads as a funnel. Tap a bar to see that day's numbers.
class _ChartCard extends StatefulWidget {
  const _ChartCard({
    required this.title,
    required this.days,
    required this.series,
  });

  final String title;
  final List<WaDayStat> days;
  final List<ChartSeries> series;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  int? _selected;

  @override
  void didUpdateWidget(_ChartCard old) {
    super.didUpdateWidget(old);
    if (old.days.length != widget.days.length) _selected = null;
  }

  int get _max {
    var m = 0;
    for (final d in widget.days) {
      for (final s in widget.series) {
        final v = s.value(d);
        if (v > m) m = v;
      }
    }
    return m;
  }

  void _pick(double dx, double width) {
    final n = widget.days.length;
    if (n == 0) return;
    final i = (dx / width * n).floor().clamp(0, n - 1);
    setState(() => _selected = _selected == i ? null : i);
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    final max = _max;
    final sel = _selected;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final s in widget.series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 12 * 1.6),
            child: sel == null
                ? Text(
                    max == 0
                        ? 'No data in this period'
                        : 'Tap a bar for the numbers',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: muted,
                    ),
                  )
                : Text(
                    "${fmtDate(days[sel].date)}:  ${widget.series.map((s) => "${s.label} ${s.value(days[sel])}").join("  ·  ")}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              return Semantics(
                image: true,
                excludeSemantics: true,
                label:
                    '${widget.title}. '
                    '${busiestDaySummary(days, widget.series) ?? 'No data in this period'}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: max == 0
                      ? null
                      : (d) => _pick(d.localPosition.dx, width),
                  child: SizedBox(
                    height: 140,
                    width: width,
                    child: CustomPaint(
                      painter: _BarPainter(
                        days: days,
                        series: widget.series,
                        max: max,
                        selected: sel,
                        axis: muted,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                days.isEmpty ? '' : fmtDate(days.first.date),
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
              ),
              Text(
                days.isEmpty ? '' : fmtDate(days.last.date),
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.days,
    required this.series,
    required this.max,
    required this.selected,
    required this.axis,
  });

  final List<WaDayStat> days;
  final List<ChartSeries> series;
  final int max;
  final int? selected;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = axis.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(fontSize: 10, color: axis);

    // Top value label and gridlines at 0, half and max.
    const labelW = 30.0;
    final chartW = size.width - labelW;
    final top = max == 0 ? 1 : max;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = size.height - 14 - (size.height - 14) * f;
      canvas.drawLine(Offset(labelW, y), Offset(size.width, y), base);
      final tp = TextPainter(
        text: TextSpan(text: '${(top * f).round()}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final n = days.length;
    if (n == 0 || max == 0) return;
    final slot = chartW / n;
    final barW = (slot * 0.7).clamp(1.5, 18.0);
    final plotH = size.height - 14;

    void bar(int i, double value, Color color, double w) {
      if (value <= 0) return;
      final h = plotH * (value / top);
      final x = labelW + slot * i + (slot - w) / 2;
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, plotH - h, w, h),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(r, Paint()..color = color);
    }

    for (var i = 0; i < n; i++) {
      if (selected == i) {
        canvas.drawRect(
          Rect.fromLTWH(labelW + slot * i, 0, slot, plotH),
          Paint()..color = axis.withValues(alpha: 0.1),
        );
      }
      // Series are drawn in order from the baseline, so with nested bars the
      // smaller ones (read, delivered) sit in front of the larger (sent).
      for (final s in series) {
        bar(i, s.value(days[i]).toDouble(), s.color, barW);
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.days != days || old.max != max || old.selected != selected;
}

class _CampaignRow extends StatelessWidget {
  const _CampaignRow({required this.stat});

  final WaCampaignStat stat;

  @override
  Widget build(BuildContext context) {
    final c = stat;
    final s = campaignStatus(c.status);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${c.name}, ${s.label}, ${c.recipients} recipients, '
          '${c.delivered} delivered (${_pct(c.deliveryRate)}), '
          '${c.read} read (${_pct(c.readRate)})'
          '${c.failed > 0 ? ', ${c.failed} failed' : ''}',
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
                    c.name,
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Mini('${c.recipients}', 'recipients'),
                _Mini('${c.delivered}', 'delivered (${_pct(c.deliveryRate)})'),
                _Mini('${c.read}', 'read (${_pct(c.readRate)})'),
                if (c.failed > 0) _Mini('${c.failed}', 'failed', bad),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.value, this.label, [this.color = ink]);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: color,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}
