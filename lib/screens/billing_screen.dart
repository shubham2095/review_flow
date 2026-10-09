import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';

String _s(dynamic v) => v?.toString() ?? '';

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v)) ?? 0;
}

int _i(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toInt() ?? 0;

String _date(dynamic v) {
  final t = _s(v);
  return t.length >= 10 ? t.substring(0, 10) : t;
}

String _rupees(double v) => '₹${v.toStringAsFixed(2)}';

/// Plan subscriptions and credit purchases are completed on the web, not in
/// the app (Google Play requires Play Billing for in-app digital goods, and
/// we use Razorpay instead). This screen only shows plans/credits/payment
/// history and hands off to a pre-authenticated web session for buying.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  Map<String, dynamic> _plans = {};
  Map<String, dynamic> _packs = {};
  Map<String, dynamic> _history = {};
  String? _error;
  bool _loading = true;
  bool _openingWeb = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.get('/billing/plans'),
        ApiService.instance.get('/billing/credit-packages'),
        ApiService.instance.get('/billing/payments'),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0];
        _packs = results[1];
        _history = results[2];
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Opens the web app in the browser, already signed in (one-time login
  /// link), so the user doesn't have to log in again just to pay.
  Future<void> _openWeb() async {
    if (_openingWeb) return;
    setState(() => _openingWeb = true);
    try {
      final res = await ApiService.instance.post('/web-session');
      await launchUrl(
        Uri.parse(res['login_url'] as String),
        mode: LaunchMode.externalApplication,
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _openingWeb = false);
    }
  }

  Future<void> _shareInvoice(int paymentId) async {
    try {
      final inv = await ApiService.instance.get(
        '/billing/payments/$paymentId/invoice',
      );
      await _sharePaymentPdf(inv);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = _s(_plans['current_plan']);
    final plans = ((_plans['plans'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final packs = ((_packs['packages'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final payments = ((_history['payments'] as List?) ?? [])
        .cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: surface,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_loading && _plans.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('😕', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: muted),
                    ),
                  ],
                ),
              )
            else ...[
              FadeIn(
                child: _CurrentPlanCard(
                  plan: currentPlan.isEmpty ? 'No active plan' : currentPlan,
                  status: _s(_plans['status']),
                  renewsAt: _date(_history['renews_at']),
                  credits: _i(_plans['credit_balance']),
                ),
              ),
              const SizedBox(height: 14),
              FadeIn(
                delay: 60,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language_rounded, color: brand),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Subscribing to a plan or buying AI credits',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'For secure payment, this is completed on the web. Tap below to open the web app — you\'ll already be signed in.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _openingWeb ? null : _openWeb,
                        icon: _openingWeb
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Continue on web'),
                      ),
                    ],
                  ),
                ),
              ),
              _Heading('Plans'),
              for (final (i, p) in plans.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeIn(
                    delay: i < 10 ? i * 70 : 0,
                    child: _PlanCard(
                      plan: p,
                      isCurrent: _s(p['code']) == currentPlan,
                      onTap: _openingWeb ? null : _openWeb,
                    ),
                  ),
                ),
              _Heading('Buy AI credits'),
              for (final (i, k) in packs.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeIn(
                    delay: i < 10 ? i * 70 : 0,
                    child: _PackCard(
                      pack: k,
                      onTap: _openingWeb ? null : _openWeb,
                    ),
                  ),
                ),
              _Heading('Payment history'),
              if (payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No payments yet.'),
                )
              else
                for (final (i, p) in payments.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FadeIn(
                      delay: i < 12 ? i * 60 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: cardDecoration(),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _s(p['plan']),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                    ),
                                  ),
                                  Text(
                                    '${_date(p['created_at'])}  •  ${_s(p['status'])}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _rupees(_n(p['amount'])),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            if (_s(p['status']) == 'PAID')
                              IconButton(
                                tooltip: 'Download invoice',
                                onPressed: () => _shareInvoice(_i(p['id'])),
                                icon: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: brand,
                                ),
                              ),
                          ],
                        ),
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

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.plan,
    required this.status,
    required this.renewsAt,
    required this.credits,
  });

  final String plan;
  final String status;
  final String renewsAt;
  final int credits;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [brand, brandDeep]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT PLAN',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plan.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Status: ${status.isEmpty ? '-' : status}  •  Renews: ${renewsAt.isEmpty ? '-' : renewsAt}  •  Credits: $credits',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onTap,
  });

  final Map<String, dynamic> plan;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final features = ((plan['features'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _s(plan['name']),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: ink,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: isCurrent
                    ? Container(
                        key: const ValueKey('current'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: good.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Current',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: good,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('not-current')),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_rupees(_n(plan['price']))} / month  •  ${_i(plan['credits'])} AI credits  •  GST ${_i(plan['gst_rate'])}%',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 8),
          for (final f in features)
            Text(
              '✓ $f',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isCurrent ? null : onTap,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(
              isCurrent ? 'Current plan' : 'Choose ${_s(plan['name'])} on web',
            ),
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack, required this.onTap});

  final Map<String, dynamic> pack;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s(pack['name']),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                Text(
                  '${_i(pack['credits'])} credits  •  ${_rupees(_n(pack['price']))} (GST ${_i(pack['gst_rate'])}%)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Buy on web'),
          ),
        ],
      ),
    );
  }
}

/// Invoice PDF for one payment. Uses "Rs." because the default PDF font has no rupee glyph.
Future<void> _sharePaymentPdf(Map<String, dynamic> inv) async {
  String money(dynamic v) => 'Rs. ${_n(v).toStringAsFixed(2)}';
  final billedTo = (inv['billed_to'] as Map?) ?? {};
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ReviewFlow',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Invoice: ${_s(inv['invoice_number'])}'),
          pw.Text('Date: ${_s(inv['date'])}'),
          pw.Text('Payment ID: ${_s(inv['payment_id'])}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Billed to',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(_s(billedTo['name'])),
          pw.Text(_s(billedTo['email'])),
          pw.SizedBox(height: 20),
          pw.Text('Plan: ${_s(inv['plan_name'])}'),
          pw.SizedBox(height: 10),
          pw.Text('Subtotal: ${money(inv['base'])}'),
          pw.Text('GST (${_i(inv['gst_rate'])}%): ${money(inv['gst'])}'),
          pw.Text(
            'Total: ${money(inv['total'])}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Status: ${_s(inv['status'])}'),
        ],
      ),
    ),
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_s(inv['invoice_number'])}.pdf');
  await file.writeAsBytes(await doc.save());
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Invoice ${_s(inv['invoice_number'])}',
    ),
  );
}
