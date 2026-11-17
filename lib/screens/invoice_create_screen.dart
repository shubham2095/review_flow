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
import '../widgets/sheet_notice.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';
import 'invoice_sheets.dart';

/// A new invoice: the customer, the dates, the lines and a live total. It is
/// saved as a draft; sending and marking paid happen on the invoice itself.
/// Pops with the new [InvoiceDetail].
class InvoiceCreateScreen extends StatefulWidget {
  const InvoiceCreateScreen({super.key});

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  List<InvoiceCustomer> _customers = [];
  List<InvoiceServiceItem> _services = [];
  InvoiceProfile _profile = const InvoiceProfile();
  String? _customerId;
  DateTime _issue = DateTime.now();
  DateTime? _due;
  final _notes = TextEditingController();
  final List<DraftLine> _lines = [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _customerId != null || _lines.isNotEmpty || _notes.text.isNotEmpty;

  Future<void> _load() async {
    try {
      final customers = await InvoicingService.customers();
      // Services and the profile only make the form nicer: do without them.
      List<InvoiceServiceItem> services = const [];
      InvoiceProfile profile = const InvoiceProfile();
      try {
        services = await InvoicingService.services();
      } catch (_) {}
      try {
        profile = await InvoicingService.profile();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _services = services;
        _profile = profile;
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

  Future<void> _pickDate({required bool due}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (due ? _due : _issue) ?? _issue,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (due) {
        _due = picked;
      } else {
        _issue = picked;
      }
    });
  }

  Future<T?> _sheet<T>(Widget sheet) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => sheet,
  );

  Future<void> _newCustomer() async {
    final c = await _sheet<InvoiceCustomer>(const CustomerQuickSheet());
    if (c == null || !mounted) return;
    setState(() {
      _customers = [..._customers, c];
      _customerId = c.id;
    });
  }

  Future<void> _editLine([int? index]) async {
    final line = await _sheet<DraftLine>(
      InvoiceLineSheet(
        services: _services,
        defaultGst: _profile.defaultGst,
        currency: _profile.currency,
        initial: index == null ? null : _lines[index],
      ),
    );
    if (line == null || !mounted) return;
    setState(() {
      if (index == null) {
        _lines.add(line);
      } else {
        _lines[index] = line;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final problem = invoiceFormProblem(
      customerId: _customerId,
      lines: _lines,
      issueDate: _issue,
      dueDate: _due,
    );
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      final created = await InvoicingService.createInvoice(
        customerId: _customerId!,
        issueDate: _issue,
        dueDate: _due,
        notes: _notes.text,
        lines: _lines,
      );
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _saving = false;
        _notice = errorLine(e);
      });
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this invoice?'),
        content: const Text('What you typed will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Widget _dateField(String label, DateTime? value, bool due) {
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label: ${value == null ? 'not set' : fmtDate(value)}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _saving ? null : () => _pickDate(due: due),
          child: InputDecorator(
            decoration: waInputDecoration(label, onWhite: false),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null ? 'Not set' : fmtDate(value),
                    style: GoogleFonts.plusJakartaSans(
                      color: value == null ? muted : ink,
                    ),
                  ),
                ),
                if (due && value != null)
                  InkWell(
                    onTap: () => setState(() => _due = null),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 18, color: muted),
                    ),
                  )
                else
                  const Icon(Icons.event_rounded, size: 18, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineTile(int i) {
    final l = _lines[i];
    final cur = _profile.currency;
    final gst = l.gstPercent ?? _profile.defaultGst;
    final base = l.quantity * l.unitPrice;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _saving ? null : () => _editLine(i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      Text(
                        '${invoiceNumber(l.quantity)} × '
                        '${invoiceMoney(l.unitPrice, cur)} + '
                        '${invoiceNumber(gst)}% GST',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  invoiceMoney(base, cur),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove line ${i + 1}',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _lines.removeAt(i)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final totals = invoiceTotals(_lines, _profile.defaultGst);
    final cur = _profile.currency;
    return Column(
      children: [
        Expanded(
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _customers.any((c) => c.id == _customerId)
                      ? _customerId
                      : null,
                  isExpanded: true,
                  decoration: waInputDecoration('Customer', onWhite: false),
                  items: [
                    for (final c in _customers)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _customerId = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _newCustomer,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(
                      _customers.isEmpty
                          ? 'Add your first customer'
                          : 'New customer',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _dateField('Date', _issue, false),
                    const SizedBox(width: 10),
                    _dateField('Due date (optional)', _due, true),
                  ],
                ),
                SectionTitle(
                  'Lines',
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  trailing: TextButton.icon(
                    onPressed: _saving ? null : () => _editLine(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add line'),
                  ),
                ),
                if (_lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Add what you are charging for: a service or an item, '
                      'with its price.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                for (var i = 0; i < _lines.length; i++) _lineTile(i),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  onChanged: (_) => setState(() {}),
                  decoration: waInputDecoration(
                    'Notes (optional)',
                    hint: 'Payment terms, thank-you line...',
                    onWhite: false,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TotalRow('Subtotal', invoiceMoney(totals.subtotal, cur)),
              _TotalRow('GST', invoiceMoney(totals.gst, cur)),
              _TotalRow('Total', invoiceMoney(totals.total, cur), bold: true),
              SheetNotice(_notice),
              const SizedBox(height: 6),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
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
                    : const Text('Save as draft'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 3, itemHeight: 82, headerHeight: 120);
    }
    final error = _error;
    if (error != null) {
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
                  title: 'Could not open the form',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    return _form();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          title: Text(
            'New invoice',
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
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: bold ? 16 : 13,
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
}
