import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/invoice_models.dart';
import '../services/invoice_pdf.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

String _money(double v) => '₹${v.toStringAsFixed(2)}';

Color _statusColor(String status) {
  switch (status) {
    case 'PAID':
      return good;
    case 'SENT':
      return brand;
    case 'OVERDUE':
      return bad;
    default:
      return muted;
  }
}

class InvoicingScreen extends StatefulWidget {
  const InvoicingScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<InvoicingScreen> createState() => _InvoicingScreenState();
}

class _InvoicingScreenState extends State<InvoicingScreen> {
  InvoiceStats? _stats;
  List<InvoiceSummary> _invoices = [];
  String? _error;
  bool _loading = true;
  final _search = TextEditingController();

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
    if (mounted) setState(() => _loading = true);
    try {
      final q = _search.text.trim();
      final json = await ApiService.instance.get(
        '/invoicing/invoices${q.isEmpty ? '' : '?q=${Uri.encodeQueryComponent(q)}'}',
      );
      if (!mounted) return;
      setState(() {
        _stats = InvoiceStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {});
        _invoices = ((json['invoices'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(InvoiceSummary.fromJson)
            .toList();
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _CreateInvoiceScreen()),
    );
    if (created == true) {
      _snack('Invoice created ✅');
      _load();
    }
  }

  Future<void> _openDetail(InvoiceSummary inv) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _InvoiceDetailSheet(invoiceId: inv.id),
    );
    if (result != null) {
      _snack(result);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text(
          'New invoice',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_stats != null) _StatsRow(stats: _stats!),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search by invoice number or client',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading && _invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('😕 $_error', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Try again')),
                  ],
                ),
              )
            else if (_invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('🧾  No invoices yet. Create your first one.')),
              )
            else
              for (final inv in _invoices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InvoiceCard(invoice: inv, onTap: () => _openDetail(inv)),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final InvoiceStats stats;

  @override
  Widget build(BuildContext context) {
    Widget tile(String emoji, String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: color),
                ),
                Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: muted)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        tile('⏳', 'Outstanding', _money(stats.outstanding), warn),
        const SizedBox(width: 8),
        tile('✅', 'Paid this month', _money(stats.paidThisMonth), good),
        const SizedBox(width: 8),
        tile('📝', 'Drafts', '${stats.drafts}', muted),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap});

  final InvoiceSummary invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(invoice.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
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
                      invoice.number,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Issued ${invoice.issueDate}${invoice.dueDate.isEmpty ? '' : '  •  Due ${invoice.dueDate}'}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(invoice.total),
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      invoiceStatusLabels[invoice.status] ?? invoice.status,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceDetailSheet extends StatefulWidget {
  const _InvoiceDetailSheet({required this.invoiceId});

  final int invoiceId;

  @override
  State<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<_InvoiceDetailSheet> {
  InvoiceDetail? _detail;
  Map<String, dynamic>? _raw;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await ApiService.instance.get('/invoicing/invoices/${widget.invoiceId}');
      if (mounted) {
        setState(() {
          _raw = json;
          _detail = InvoiceDetail.fromJson(json);
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _action(String path, String successMessage, {Map<String, dynamic>? body}) async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.post(path, body: body);
      if (mounted) Navigator.of(context).pop(successMessage);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.delete('/invoicing/invoices/${widget.invoiceId}');
      if (mounted) Navigator.of(context).pop('Draft invoice deleted');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: d == null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: _error == null
                  ? const Center(child: CircularProgressIndicator())
                  : Text(_error!, textAlign: TextAlign.center),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: muted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.number,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
                        ),
                      ),
                      Text(
                        invoiceStatusLabels[d.status] ?? d.status,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: _statusColor(d.status),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.clientName}  •  Issued ${d.issueDate}${d.dueDate.isEmpty ? '' : '  •  Due ${d.dueDate}'}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 14),
                  for (final line in d.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${line.description}\n${line.quantity.toStringAsFixed(0)} × ${_money(line.unitPrice)} + ${line.gstPercent.toStringAsFixed(0)}% GST',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink, height: 1.4),
                            ),
                          ),
                          Text(
                            _money(line.amount),
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  _TotalRow(label: 'Subtotal', value: _money(d.subtotal)),
                  _TotalRow(label: 'GST', value: _money(d.gstTotal)),
                  _TotalRow(label: 'Total', value: _money(d.total), bold: true),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _raw == null
                        ? null
                        : () async {
                            try {
                              await shareInvoicePdf(_raw!);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(friendlyException(e).message)),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Download PDF'),
                  ),
                  const SizedBox(height: 18),
                  if (d.status == 'DRAFT')
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _action('/invoicing/invoices/${d.id}/send', 'Invoice marked as sent'),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Mark as sent'),
                    ),
                  if (d.status == 'SENT' || d.status == 'OVERDUE') ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _action('/invoicing/invoices/${d.id}/paid', 'Invoice marked as paid ✅'),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Mark as paid'),
                      style: FilledButton.styleFrom(backgroundColor: good),
                    ),
                  ],
                  if (d.status == 'DRAFT') ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline_rounded, color: bad),
                      label: const Text('Delete draft', style: TextStyle(color: bad)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.plusJakartaSans(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: ink,
      fontSize: bold ? 15 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ItemDraft {
  _ItemDraft()
      : description = TextEditingController(),
        quantity = TextEditingController(text: '1'),
        price = TextEditingController(),
        gst = TextEditingController(text: '18');

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController price;
  final TextEditingController gst;

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
    gst.dispose();
  }

  double get qty => double.tryParse(quantity.text) ?? 0;
  double get unit => double.tryParse(price.text) ?? 0;
  double get gstPct => double.tryParse(gst.text) ?? 0;
  double get lineTotal => qty * unit * (1 + gstPct / 100);
}

class _CreateInvoiceScreen extends StatefulWidget {
  const _CreateInvoiceScreen();

  @override
  State<_CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<_CreateInvoiceScreen> {
  List<CustomerOption> _customers = [];
  int? _clientId;
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  final _notes = TextEditingController();
  final List<_ItemDraft> _items = [_ItemDraft()];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final list = await ApiService.instance.getList('/invoicing/customers');
      if (!mounted) return;
      setState(() {
        _customers = list.cast<Map<String, dynamic>>().map(CustomerOption.fromJson).toList();
        if (_customers.isNotEmpty) _clientId = _customers.first.id;
      });
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool due}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: due ? (_dueDate ?? _issueDate.add(const Duration(days: 15))) : _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() => due ? _dueDate = picked : _issueDate = picked);
  }

  double get _total => _items.fold(0, (sum, i) => sum + i.lineTotal);

  Future<void> _save() async {
    if (_clientId == null) {
      _message('Pick a client first');
      return;
    }
    final valid = _items.where((i) => i.description.text.trim().isNotEmpty && i.unit > 0).toList();
    if (valid.isEmpty) {
      _message('Add at least one item with a description and price');
      return;
    }

    setState(() => _busy = true);
    try {
      await ApiService.instance.post('/invoicing/invoices', body: {
        'client_id': _clientId,
        'issue_date': _fmt(_issueDate),
        if (_dueDate != null) 'due_date': _fmt(_dueDate!),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'items': [
          for (final i in valid)
            {
              'description': i.description.text.trim(),
              'quantity': i.qty,
              'unit_price': i.unit,
              'gst_percent': i.gstPct,
            },
        ],
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        title: Text('New invoice', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Add a customer first, then create an invoice.', textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _clientId,
                      decoration: _dec('Customer'),
                      items: [
                        for (final c in _customers) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(due: false),
                            icon: const Icon(Icons.event_rounded, size: 18),
                            label: Text('Issue ${_fmt(_issueDate)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(due: true),
                            icon: const Icon(Icons.event_available_rounded, size: 18),
                            label: Text(_dueDate == null ? 'Due date' : 'Due ${_fmt(_dueDate!)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Items', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _items.length; i++)
                      _ItemEditor(
                        draft: _items[i],
                        onChanged: () => setState(() {}),
                        onRemove: _items.length > 1
                            ? () => setState(() {
                                  _items[i].dispose();
                                  _items.removeAt(i);
                                })
                            : null,
                      ),
                    TextButton.icon(
                      onPressed: () => setState(() => _items.add(_ItemDraft())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add item'),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _notes, maxLines: 3, decoration: _dec('Notes (optional)')),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration(),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Total (incl. GST)',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink)),
                          ),
                          Text(
                            _money(_total),
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: brand),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save as draft'),
                    ),
                  ],
                ),
    );
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({required this.draft, required this.onChanged, this.onRemove});

  final _ItemDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.description,
                  decoration: _dec('Description'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, color: bad),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Qty'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('Price'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: draft.gst,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _dec('GST %'),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Line total: ${_money(draft.lineTotal)}',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
