import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

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
import '../widgets/wa_ui.dart';

/// One invoice: who, when, the lines and totals, and what you can do next
/// (mark sent, mark paid, delete a draft, share a copy). Pops with true when
/// something changed so the list reloads.
class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    this.number = '',
  });

  final String invoiceId;

  /// The number from the list, shown in the title while this loads.
  final String number;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  InvoiceWithProfile? _data;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await InvoicingService.invoice(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _data = d;
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

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      _changed = true;
      if (!mounted) return;
      showToast(context, message);
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markSent(InvoiceDetail inv) async {
    if (!await _confirm(
      title: 'Mark ${inv.number} as sent?',
      text:
          'This only records that you sent it to the customer. Nothing is '
          'sent from here: use Share to send them a copy.',
      action: 'Mark as sent',
    )) {
      return;
    }
    await _run(() => InvoicingService.markSent(inv.id));
  }

  Future<void> _markPaid(InvoiceDetail inv) async {
    if (!await _confirm(
      title: 'Mark ${inv.number} as paid?',
      text: 'It is recorded as paid today.',
      action: 'Mark as paid',
    )) {
      return;
    }
    await _run(() => InvoicingService.markPaid(inv.id));
  }

  Future<void> _delete(InvoiceDetail inv) async {
    if (!await _confirm(
      title: 'Delete ${inv.number}?',
      text: 'The draft is removed. Only drafts can be deleted.',
      action: 'Delete',
      danger: true,
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await InvoicingService.deleteInvoice(inv.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, errorLine(e));
      }
    }
  }

  Future<void> _share(InvoiceWithProfile d) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: invoiceShareText(d.invoice, d.profile),
          subject: 'Invoice ${d.invoice.number}',
        ),
      );
    } catch (_) {
      if (mounted) showToast(context, 'Could not share this invoice.');
    }
  }

  Widget _kv(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        container: true,
        label: '$label $value',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(InvoiceDetail inv) {
    final (label, color) = invoiceStatus(inv.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inv.number,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: ink,
                  ),
                ),
              ),
              StatusBadge(label, color),
            ],
          ),
          const SizedBox(height: 10),
          _kv('Customer', inv.customerName),
          _kv('Date', inv.issueDate == null ? '' : fmtDate(inv.issueDate!)),
          _kv('Due', inv.dueDate == null ? '' : fmtDate(inv.dueDate!)),
          _kv('Paid on', inv.paidAt == null ? '' : fmtDate(inv.paidAt!)),
        ],
      ),
    );
  }

  Widget _lines(InvoiceDetail inv, String cur) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in inv.lines)
            Semantics(
              container: true,
              excludeSemantics: true,
              label:
                  '${l.description}, ${invoiceNumber(l.quantity)} times '
                  '${invoiceMoney(l.unitPrice, cur)}, ${invoiceNumber(l.gstPercent)} '
                  'percent GST, ${invoiceMoney(l.amount, cur)}',
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.description,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          Text(
                            '${invoiceNumber(l.quantity)} × '
                            '${invoiceMoney(l.unitPrice, cur)} + '
                            '${invoiceNumber(l.gstPercent)}% GST',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      invoiceMoney(l.amount, cur),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 8),
          const SizedBox(height: 8),
          _total('Subtotal', invoiceMoney(inv.subtotal, cur)),
          _total('GST', invoiceMoney(inv.gstTotal, cur)),
          _total('Total', invoiceMoney(inv.total, cur), bold: true),
        ],
      ),
    );
  }

  Widget _total(String label, String value, {bool bold = false}) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: bold ? 17 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: bold ? ink : inkSoft,
    );
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(value, style: style),
          ],
        ),
      ),
    );
  }

  Widget _from(InvoiceProfile p) {
    final hasBank = p.bankName.isNotEmpty || p.bankAccount.isNotEmpty;
    if (p.companyName.isEmpty && !hasBank) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('From', p.companyName),
            _kv('GSTIN', p.gstin),
            _kv('Phone', p.phone),
            _kv('Email', p.email),
            _kv('Address', p.address),
            if (hasBank) ...[
              const SizedBox(height: 6),
              _kv('Bank', p.bankName),
              _kv('Account', p.bankAccount),
              _kv('IFSC', p.ifsc),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _actions(InvoiceDetail inv) {
    final buttons = <Widget>[
      if (inv.isDraft)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _delete(inv),
            style: OutlinedButton.styleFrom(foregroundColor: bad),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ),
      if (inv.isDraft)
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _markSent(inv),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Mark as sent'),
          ),
        ),
      if (!inv.isDraft && !inv.isPaid)
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _markPaid(inv),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Mark as paid'),
          ),
        ),
    ];
    if (buttons.isEmpty) return null;
    final spaced = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 10));
      spaced.add(buttons[i]);
    }
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(children: spaced),
    );
  }

  Widget _body(InvoiceWithProfile d) {
    final inv = d.invoice;
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ContentWidth(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _summary(inv),
            const SizedBox(height: 12),
            _lines(inv, d.profile.currency),
            if (inv.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: cardDecoration(),
                  child: Text(
                    inv.notes,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: inkSoft,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            _from(d.profile),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final error = _error;
    Widget body;
    if (_loading) {
      body = const SkeletonList(count: 3, itemHeight: 82, headerHeight: 130);
    } else if (error != null && d == null) {
      final access = accessProblem(error);
      body = Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load this invoice',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    } else {
      body = _body(d!);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          title: Text(
            d?.invoice.number ??
                (widget.number.isEmpty ? 'Invoice' : widget.number),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: ink,
          actions: [
            if (d != null)
              IconButton(
                tooltip: 'Share invoice',
                icon: const Icon(Icons.share_rounded),
                onPressed: () => _share(d),
              ),
          ],
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: body),
          ],
        ),
        bottomNavigationBar: d == null ? null : _actions(d.invoice),
      ),
    );
  }
}
