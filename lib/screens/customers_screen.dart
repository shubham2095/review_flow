import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/customer_expense_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];
  String? _error;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await ApiService.instance.getList('/invoicing/customers');
      if (!mounted) return;
      setState(() {
        _customers = list
            .cast<Map<String, dynamic>>()
            .map(Customer.fromJson)
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

  Future<void> _openSheet({Customer? customer}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CustomerSheet(customer: customer),
    );
    if (result == 'added') _snack('Customer added ✅');
    if (result == 'updated') _snack('Customer updated ✅');
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _customers
        .where(
          (c) =>
              _query.isEmpty ||
              c.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          'Add customer',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            FadeIn(
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search customers',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading && _customers.isEmpty)
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
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (filtered.isEmpty)
              FadeIn(
                delay: 80,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('👥', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          'No customers yet',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add your first customer.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              for (final (i, c) in filtered.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeIn(
                    delay: i < 12 ? i * 60 : 0,
                    child: _CustomerCard(
                      customer: c,
                      onTap: () => _openSheet(customer: c),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.isEmpty
        ? '?'
        : customer.name[0].toUpperCase();
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
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: brand.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: brand,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        customer.phone,
                        customer.email,
                      ].where((e) => e.isNotEmpty).join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: muted,
                      ),
                    ),
                    if (customer.gstin.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'GSTIN ${customer.gstin}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${customer.invoicesCount}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  Text(
                    'invoices',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: muted,
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

class _CustomerSheet extends StatefulWidget {
  const _CustomerSheet({this.customer});

  final Customer? customer;

  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  late final _name = TextEditingController(text: widget.customer?.name ?? '');
  late final _phone = TextEditingController(text: widget.customer?.phone ?? '');
  late final _email = TextEditingController(text: widget.customer?.email ?? '');
  late final _gstin = TextEditingController(text: widget.customer?.gstin ?? '');
  late final _address = TextEditingController(
    text: widget.customer?.billingAddress ?? '',
  );
  bool _busy = false;

  bool get _isEdit => widget.customer != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _gstin.dispose();
    _address.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('Name is required');
      return;
    }
    final body = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'gstin': _gstin.text.trim(),
      'billing_address': _address.text.trim(),
    };

    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await ApiService.instance.put(
          '/invoicing/customers/${widget.customer!.id}',
          body: body,
        );
        if (mounted) Navigator.of(context).pop('updated');
      } else {
        await ApiService.instance.post('/invoicing/customers', body: body);
        if (mounted) Navigator.of(context).pop('added');
      }
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
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Edit customer' : 'Add customer',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ink,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: _dec('Name *')),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gstin,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('GSTIN'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              maxLines: 2,
              decoration: _dec('Billing address'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add customer'),
            ),
          ],
        ),
      ),
    );
  }
}
