import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

String _s(dynamic v) => v?.toString() ?? '';

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v)) ?? 0;
}

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.getList('/invoicing/services'),
        ApiService.instance.getList('/invoicing/categories'),
      ]);
      if (!mounted) return;
      setState(() {
        _services = (results[0]).cast<Map<String, dynamic>>();
        _categories = (results[1]).cast<Map<String, dynamic>>();
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

  Future<void> _openSheet({Map<String, dynamic>? service}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ServiceSheet(service: service, categories: _categories),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add service', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading && _services.isEmpty
            ? ListView(children: const [SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))])
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!))])
                : _services.isEmpty
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('🧾  No services yet. Add your first service.')),
                        ),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: _services.length,
                        itemBuilder: (_, i) {
                          final s = _services[i];
                          final active = _s(s['status']) == 'ACTIVE';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _openSheet(service: s),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: cardDecoration(),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_s(s['name']),
                                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_s(s['category']).isEmpty ? 'Uncategorized' : _s(s['category'])}  •  GST ${_d(s['gst_percent']).toStringAsFixed(0)}%',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₹${_d(s['price']).toStringAsFixed(2)}',
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (active ? good : muted).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              active ? 'Active' : 'Inactive',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: active ? good : muted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ServiceSheet extends StatefulWidget {
  const _ServiceSheet({this.service, required this.categories});

  final Map<String, dynamic>? service;
  final List<Map<String, dynamic>> categories;

  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  late final _name = TextEditingController(text: _s(widget.service?['name']));
  late final _price = TextEditingController(text: widget.service == null ? '' : _d(widget.service!['price']).toString());
  late final _gst = TextEditingController(
    text: widget.service == null ? '18' : _d(widget.service!['gst_percent']).toString(),
  );
  late int? _categoryId = (widget.service?['service_category_id'] as num?)?.toInt();
  late bool _active = _s(widget.service?['status']) != 'INACTIVE';
  bool _busy = false;

  bool get _isEdit => widget.service != null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _gst.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty) {
      _message('Service name is required');
      return;
    }
    if (price == null || price < 0) {
      _message('Enter a valid price');
      return;
    }
    final body = {
      'name': _name.text.trim(),
      'service_category_id': _categoryId,
      'price': price,
      'gst_percent': double.tryParse(_gst.text.trim()) ?? 18,
      if (_isEdit) 'status': _active ? 'ACTIVE' : 'INACTIVE',
    };
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await ApiService.instance.put('/invoicing/services/${widget.service!['id']}', body: body);
      } else {
        await ApiService.instance.post('/invoicing/services', body: body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.delete('/invoicing/services/${widget.service!['id']}');
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
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
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
            Text(
              _isEdit ? 'Edit service' : 'Add service',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
            ),
            const SizedBox(height: 14),
            TextField(controller: _name, decoration: _dec('Service name *')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              isExpanded: true,
              initialValue: _categoryId,
              decoration: _dec('Category'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Uncategorized')),
                for (final c in widget.categories)
                  DropdownMenuItem<int?>(value: (c['id'] as num?)?.toInt(), child: Text(_s(c['name']))),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Price (₹) *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _gst,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('GST %'),
                  ),
                ),
              ],
            ),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
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
                  : Text(_isEdit ? 'Save changes' : 'Add service'),
            ),
            if (_isEdit)
              TextButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, color: bad),
                label: const Text('Delete service', style: TextStyle(color: bad)),
              ),
          ],
        ),
      ),
    );
  }
}
