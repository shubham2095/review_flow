import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/invoicing_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/invoicing_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/invoice_format.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/tab_label.dart';
import '../widgets/text_scale.dart';
import '../widgets/wa_ui.dart';
import 'invoice_catalog.dart';
import 'invoice_create_screen.dart';
import 'invoice_detail_screen.dart';

/// The rows with this status, or all of them for `null`.
List<InvoiceRow> filterInvoices(List<InvoiceRow> rows, String? status) =>
    status == null
    ? rows
    : rows.where((r) => r.status.toUpperCase() == status).toList();

/// Invoicing: the money owed and received, and every invoice with a search
/// and a status filter. A page of the home shell (no app bar of its own).
class InvoicesTab extends StatefulWidget {
  const InvoicesTab({super.key});

  @override
  State<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<InvoicesTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  InvoiceList? _data;
  String _currency = 'INR';
  String? _status;
  bool _loading = true;
  bool _refreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    if (!first) setState(() => _refreshing = true);
    try {
      final query = _search.text;
      final data = await InvoicingService.invoices(query: query);
      // The currency only decorates the amounts; keep the last one on failure.
      var currency = _currency;
      if (first) {
        try {
          currency = (await InvoicingService.profile()).currency;
        } catch (_) {}
      }
      if (!mounted || query != _search.text) return;
      setState(() {
        _data = data;
        _currency = currency;
        _error = null;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<InvoiceDetail>(
      MaterialPageRoute(builder: (_) => const InvoiceCreateScreen()),
    );
    if (created == null || !mounted) return;
    showToast(context, 'Draft ${created.number} saved.');
    await _load();
    if (mounted) _open(created.id, created.number);
  }

  Future<void> _open(String id, String number) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(invoiceId: id, number: number),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Widget _stats(InvoiceStats s) {
    return Row(
      children: [
        Expanded(
          child: _MoneyTile(
            label: 'To receive',
            value: invoiceMoney(s.outstanding, _currency),
            icon: Icons.hourglass_bottom_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MoneyTile(
            label: 'Paid this month',
            value: invoiceMoney(s.paidThisMonth, _currency),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MoneyTile(
            label: 'Drafts',
            value: '${s.drafts}',
            icon: Icons.edit_note_rounded,
          ),
        ),
      ],
    );
  }

  Widget _filters() {
    const options = <(String?, String)>[
      (null, 'All'),
      ('DRAFT', 'Draft'),
      ('SENT', 'Sent'),
      ('OVERDUE', 'Overdue'),
      ('PAID', 'Paid'),
    ];
    return SizedBox(
      height: textScaled(context, 44),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _status == value,
                onSelected: (_) => setState(() => _status = value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(InvoiceRow r) {
    final (label, color) = invoiceStatus(r.status);
    final due = r.dueDate == null ? '' : 'Due ${fmtDate(r.dueDate!)}';
    final date = r.issueDate == null ? '' : fmtDate(r.issueDate!);
    final money = invoiceMoney(r.total, _currency);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${r.number}, ${r.customerName}, $money, $label'
          '${due.isEmpty ? '' : ', $due'}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: cardDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _open(r.id, r.number),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.customerName.isEmpty ? r.number : r.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        Text(
                          [
                            r.number,
                            date,
                          ].where((t) => t.isNotEmpty).join(' · '),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                        if (due.isNotEmpty)
                          Text(
                            due,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: r.status.toUpperCase() == 'OVERDUE'
                                  ? bad
                                  : muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(label, color),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 82, headerHeight: 96);
    }
    final error = _error;
    final data = _data;
    if (error != null && data == null) {
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
                  title: 'Could not load invoices',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load(first: true);
                  },
                ),
        ),
      );
    }
    final rows = filterInvoices(data!.rows, _status);
    final searching = _search.text.trim().isNotEmpty;
    // Rows: stats, search, filters, the "count and New invoice" line, then
    // one row per invoice (or one empty note), built lazily.
    const lead = 4;
    return RefreshIndicator(
      color: brand,
      onRefresh: () => _load(),
      child: ContentWidth(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: lead + (rows.isEmpty ? 1 : rows.length),
          itemBuilder: (_, i) {
            switch (i) {
              case 0:
                return _stats(data.stats);
              case 1:
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration:
                        waInputDecoration(
                          'Search by number or customer',
                          onWhite: false,
                        ).copyWith(
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _refreshing
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                  ),
                );
              case 2:
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _filters(),
                );
              case 3:
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${rows.length} ${rows.length == 1 ? 'invoice' : 'invoices'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: muted,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New invoice'),
                      ),
                    ],
                  ),
                );
            }
            if (rows.isEmpty) {
              return StateView(
                icon: Icons.receipt_long_outlined,
                title: searching || _status != null
                    ? 'No invoices match'
                    : 'No invoices yet',
                text: searching || _status != null
                    ? 'Try a different search or filter.'
                    : 'Create your first invoice for a customer.',
              );
            }
            return _row(rows[i - lead]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _body();
}

/// Invoicing: invoices, and the catalog they are made from (customers,
/// services, categories). A page of the home shell (no app bar of its own).
class InvoicingScreen extends StatefulWidget {
  const InvoicingScreen({super.key});

  @override
  State<InvoicingScreen> createState() => _InvoicingScreenState();
}

class _InvoicingScreenState extends State<InvoicingScreen> {
  int _tab = 0;

  // A tab is built the first time it is shown and then kept, so its search and
  // scroll position survive switching.
  final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          const OfflineBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: TabLabel('Invoices')),
                  ButtonSegment(value: 1, label: TabLabel('Catalog')),
                ],
                selected: {_tab},
                onSelectionChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _tab = v.first;
                    _visited.add(_tab);
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                const InvoicesTab(),
                if (_visited.contains(1))
                  const InvoiceCatalogTab()
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  const _MoneyTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: brand),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
