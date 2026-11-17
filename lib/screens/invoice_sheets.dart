import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/invoicing_models.dart';
import '../services/access_problem.dart';
import '../services/invoicing_service.dart';
import '../widgets/invoice_format.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_ui.dart';

double? _number(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// Adds or edits one line of an invoice. Pops with the [DraftLine].
class InvoiceLineSheet extends StatefulWidget {
  const InvoiceLineSheet({
    super.key,
    this.services = const [],
    this.defaultGst = 18,
    this.currency = 'INR',
    this.initial,
  });

  /// What you sell, to fill the line in one tap (optional).
  final List<InvoiceServiceItem> services;
  final double defaultGst;
  final String currency;
  final DraftLine? initial;

  @override
  State<InvoiceLineSheet> createState() => _InvoiceLineSheetState();
}

class _InvoiceLineSheetState extends State<InvoiceLineSheet> {
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _quantity = TextEditingController(
    text: invoiceNumber(widget.initial?.quantity ?? 1),
  );
  late final _price = TextEditingController(
    text: widget.initial == null
        ? ''
        : invoiceNumber(widget.initial!.unitPrice),
  );
  late final _gst = TextEditingController(
    text: widget.initial?.gstPercent == null
        ? ''
        : invoiceNumber(widget.initial!.gstPercent!),
  );
  String? _serviceId;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _serviceId = widget.initial?.serviceId;
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    _gst.dispose();
    super.dispose();
  }

  void _pickService(String? id) {
    setState(() => _serviceId = id);
    if (id == null) return;
    final s = widget.services.firstWhere((x) => x.id == id);
    _description.text = s.name;
    _price.text = invoiceNumber(s.price);
    _gst.text = invoiceNumber(s.gstPercent);
  }

  void _save() {
    final gstText = _gst.text.trim();
    final gst = gstText.isEmpty ? null : _number(gstText);
    final problem = invoiceLineProblem(
      description: _description.text,
      quantity: _number(_quantity.text),
      unitPrice: _number(_price.text),
      gstPercent: gstText.isNotEmpty && gst == null ? -1 : gst,
    );
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    Navigator.of(context).pop(
      DraftLine(
        description: _description.text.trim(),
        quantity: _number(_quantity.text)!,
        unitPrice: _number(_price.text)!,
        gstPercent: gst,
        serviceId: _serviceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    return AppSheet(
      title: widget.initial == null ? 'Add a line' : 'Edit line',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.services.isNotEmpty) ...[
            DropdownButtonFormField<String?>(
              initialValue: widget.services.any((s) => s.id == _serviceId)
                  ? _serviceId
                  : null,
              isExpanded: true,
              decoration: waInputDecoration(
                'Pick from your services (optional)',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Type my own')),
                for (final s in widget.services.where((s) => s.active))
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.name} · ${invoiceMoney(s.price, widget.currency)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _pickService,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _description,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: waInputDecoration('What is it for?'),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantity,
                  keyboardType: numberKeyboard,
                  decoration: waInputDecoration('Quantity'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: numberKeyboard,
                  decoration: waInputDecoration('Price each'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _gst,
            keyboardType: numberKeyboard,
            decoration: waInputDecoration(
              'GST % (optional)',
              hint: invoiceNumber(widget.defaultGst),
              helper:
                  'Leave empty to use your usual ${invoiceNumber(widget.defaultGst)}%.',
            ),
          ),
          const SizedBox(height: 12),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _save,
            child: Text(widget.initial == null ? 'Add line' : 'Save line'),
          ),
        ],
      ),
    );
  }
}

/// What is wrong with a new customer, or null.
String? customerProblem({required String name, required String email}) {
  if (name.trim().isEmpty) return 'Write the customer\'s name.';
  final e = email.trim();
  if (e.isNotEmpty && (!e.contains('@') || !e.contains('.'))) {
    return 'That email address does not look right.';
  }
  return null;
}

/// Adds or edits a customer (also used from the invoice form without leaving
/// it). Pops with the saved [InvoiceCustomer].
class CustomerSheet extends StatefulWidget {
  const CustomerSheet({super.key, this.customer});

  /// Null to add a new customer.
  final InvoiceCustomer? customer;

  @override
  State<CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<CustomerSheet> {
  late final _name = TextEditingController(text: widget.customer?.name ?? '');
  late final _phone = TextEditingController(text: widget.customer?.phone ?? '');
  late final _email = TextEditingController(text: widget.customer?.email ?? '');
  late final _gstin = TextEditingController(text: widget.customer?.gstin ?? '');
  late final _address = TextEditingController(
    text: widget.customer?.billingAddress ?? '',
  );
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _gstin.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = customerProblem(name: _name.text, email: _email.text);
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final existing = widget.customer;
      final InvoiceCustomer saved;
      if (existing == null) {
        saved = await InvoicingService.addCustomer(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          gstin: _gstin.text.trim(),
          billingAddress: _address.text.trim(),
        );
      } else {
        await InvoicingService.updateCustomer(
          existing.id,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          gstin: _gstin.text.trim(),
          billingAddress: _address.text.trim(),
        );
        saved = InvoiceCustomer(
          id: existing.id,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          gstin: _gstin.text.trim(),
          billingAddress: _address.text.trim(),
          invoicesCount: existing.invoicesCount,
        );
      }
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _busy = false;
        _notice = errorLine(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: widget.customer == null ? 'New customer' : 'Edit customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: waInputDecoration('Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            decoration: waInputDecoration('Phone (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: waInputDecoration('Email (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _gstin,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            maxLength: 20,
            decoration: waInputDecoration('GSTIN (optional)'),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _address,
            enabled: !_busy,
            minLines: 2,
            maxLines: 3,
            maxLength: 255,
            decoration: waInputDecoration('Billing address (optional)'),
          ),
          const SizedBox(height: 8),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
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
                : Text(
                    widget.customer == null ? 'Add customer' : 'Save changes',
                  ),
          ),
        ],
      ),
    );
  }
}
