import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';
import '../widgets/skeleton.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import 'admin_company_filters.dart';

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
  final _search = TextEditingController();
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

  String _statusLabel(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

  /// The count line, a note about the 500-row limit, and one row per payment
  /// that passes the search and the status chip.
  List<Widget> _rows(AdminPaymentsData d) {
    final shown = filterPayments(
      d.payments,
      query: _search.text,
      status: _status,
    );
    final filtering = _search.text.trim().isNotEmpty || _status != null;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
        child: Text(
          filtering
              ? '${shown.length} of ${d.payments.length} payments'
              : '${d.payments.length} payments'
                    '${d.payments.length >= 500 ? ' (latest 500)' : ''}',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
        ),
      ),
      if (shown.isEmpty)
        const AdminMessage(
          icon: Icons.search_off_rounded,
          title: 'No payments match',
          text: 'Try a different search or status.',
        )
      else
        for (var i = 0; i < shown.length; i++)
          FadeIn(
            delay: i < 8 ? i * 40 : 0,
            child: _PaymentRow(payment: shown[i]),
          ),
    ];
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
            ? const SkeletonList(count: 4, itemHeight: 84, headerHeight: 90)
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
                    else ...[
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration:
                            adminInput(
                              'Search by company, number or plan',
                            ).copyWith(
                              prefixIcon: const Icon(Icons.search_rounded),
                              fillColor: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final s in <String?>[
                              null,
                              ...paymentStatuses(d.payments),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    s == null ? 'All' : _statusLabel(s),
                                  ),
                                  selected: _status == s,
                                  onSelected: (_) =>
                                      setState(() => _status = s),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ..._rows(d),
                    ],
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
