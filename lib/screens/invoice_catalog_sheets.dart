import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/invoicing_models.dart';
import '../services/access_problem.dart';
import '../services/invoicing_service.dart';
import '../widgets/invoice_format.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_ui.dart';

double? _number(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// What is wrong with a service, or null.
String? serviceProblem({
  required String name,
  required double? price,
  required double? gstPercent,
}) {
  if (name.trim().isEmpty) return 'Write the service name.';
  if (price == null || price < 0) return 'Write the price (0 or more).';
  if (gstPercent == null || gstPercent < 0 || gstPercent > 100) {
    return 'GST must be between 0 and 100.';
  }
  return null;
}

/// Adds or edits a service you sell. Pops with true when saved.
class ServiceSheet extends StatefulWidget {
  const ServiceSheet({
    super.key,
    this.categories = const [],
    this.defaultGst = 18,
    this.service,
  });

  final List<InvoiceCategory> categories;
  final double defaultGst;

  /// Null to add a new service.
  final InvoiceServiceItem? service;

  @override
  State<ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<ServiceSheet> {
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _price = TextEditingController(
    text: widget.service == null ? '' : invoiceNumber(widget.service!.price),
  );
  late final _gst = TextEditingController(
    text: invoiceNumber(widget.service?.gstPercent ?? widget.defaultGst),
  );
  late String? _category =
      widget.categories.any((c) => c.id == widget.service?.categoryId)
      ? widget.service!.categoryId
      : null;
  late bool _active = widget.service?.active ?? true;
  bool _busy = false;
  String? _notice;

  bool get _isNew => widget.service == null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _gst.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = _number(_price.text);
    final gst = _number(_gst.text);
    final problem = serviceProblem(
      name: _name.text,
      price: price,
      gstPercent: gst,
    );
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
      if (_isNew) {
        await InvoicingService.addService(
          name: _name.text.trim(),
          price: price!,
          gstPercent: gst!,
          categoryId: _category,
        );
      } else {
        await InvoicingService.updateService(
          widget.service!.id,
          name: _name.text.trim(),
          price: price!,
          gstPercent: gst!,
          categoryId: _category,
          active: _active,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
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
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);
    return AppSheet(
      title: _isNew ? 'New service' : 'Edit service',
      subtitle: 'Something you sell. Pick it on an invoice to fill the line.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            decoration: waInputDecoration('Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _category,
            isExpanded: true,
            decoration: waInputDecoration('Category (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No category')),
              for (final c in widget.categories)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy ? null : (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  enabled: !_busy,
                  keyboardType: numberKeyboard,
                  decoration: waInputDecoration('Price'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _gst,
                  enabled: !_busy,
                  keyboardType: numberKeyboard,
                  decoration: waInputDecoration('GST %'),
                ),
              ),
            ],
          ),
          if (!_isNew)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Inactive services are hidden on invoices'),
              value: _active,
              onChanged: _busy ? null : (v) => setState(() => _active = v),
            ),
          const SizedBox(height: 12),
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
                : Text(_isNew ? 'Add service' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}

/// Adds a category to group services. Pops with true when saved.
class CategorySheet extends StatefulWidget {
  const CategorySheet({super.key});

  @override
  State<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<CategorySheet> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _notice = 'Write the category name.');
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await InvoicingService.addCategory(_name.text.trim());
      if (mounted) Navigator.of(context).pop(true);
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
      title: 'New category',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            maxLength: 255,
            textCapitalization: TextCapitalization.words,
            decoration: waInputDecoration('Name', hint: 'Design, Hosting...'),
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
                : const Text('Add category'),
          ),
        ],
      ),
    );
  }
}
