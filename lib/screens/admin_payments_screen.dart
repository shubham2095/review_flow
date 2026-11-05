import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';

/// Every plan invoice across all companies, newest first.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  AdminPaymentsData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AdminService.payments();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;

    return Scaffold(
      backgroundColor: surface,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null)
                    AdminMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load payments',
                      text: _error!,
                      onRetry: _load,
                    )
                  else if (d != null) ...[
                    FadeIn(
                      child: Row(
                        children: [
                          _Stat('Payments', '${d.count}', brand),
                          const SizedBox(width: 8),
                          _Stat('Paid', '${d.paid}', good),
                          const SizedBox(width: 8),
                          _Stat('Revenue', d.revenue, royalIndigo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (d.payments.isEmpty)
                      const AdminMessage(
                        icon: Icons.receipt_long_outlined,
                        title: 'No payments yet',
                      )
                    else
                      for (var i = 0; i < d.payments.length; i++)
                        FadeIn(
                          delay: i < 8 ? i * 40 : 0,
                          child: _PaymentRow(payment: d.payments[i]),
                        ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: cardDecoration(),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final AdminPayment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final detail = [
      if ((p.plan ?? '').isNotEmpty) p.plan!,
      if ((p.gateway ?? '').isNotEmpty) p.gateway!,
      if (p.issuedAt != null) fmtDate(p.issuedAt!),
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.company,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.number,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                p.total,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              AdminBadge(p.status, adminStatusColor(p.status)),
            ],
          ),
        ],
      ),
    );
  }
}
