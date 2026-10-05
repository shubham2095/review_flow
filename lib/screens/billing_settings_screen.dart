import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

class BillingSettingsScreen extends StatefulWidget {
  const BillingSettingsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<BillingSettingsScreen> createState() => _BillingSettingsScreenState();
}

class _BillingSettingsScreenState extends State<BillingSettingsScreen> {
  final _companyName = TextEditingController();
  final _businessType = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _state = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _invoicePrefix = TextEditingController();
  final _defaultGst = TextEditingController();
  final _currency = TextEditingController();
  bool _roundTotal = false;
  String _nextNumber = '';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _companyName, _businessType, _phone, _email, _gstin, _address, _state,
      _bankName, _bankAccount, _ifsc, _invoicePrefix, _defaultGst, _currency,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _s(dynamic v) => v?.toString() ?? '';

  Future<void> _load() async {
    try {
      final j = await ApiService.instance.get('/invoicing/settings');
      if (!mounted) return;
      setState(() {
        _companyName.text = _s(j['company_name']);
        _businessType.text = _s(j['business_type']);
        _phone.text = _s(j['phone']);
        _email.text = _s(j['email']);
        _gstin.text = _s(j['gstin']);
        _address.text = _s(j['address']);
        _state.text = _s(j['state']);
        _bankName.text = _s(j['bank_name']);
        _bankAccount.text = _s(j['bank_account']);
        _ifsc.text = _s(j['ifsc']);
        _invoicePrefix.text = _s(j['invoice_prefix']);
        _defaultGst.text = _s(j['default_gst']);
        _currency.text = _s(j['currency']);
        _roundTotal = j['round_total'] == true;
        _nextNumber = '${_s(j['invoice_prefix'])}-${_s(j['next_invoice_number']).padLeft(4, '0')}';
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_invoicePrefix.text.trim().isEmpty) {
      _snack('Invoice prefix is required');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.instance.put('/invoicing/settings', body: {
        'company_name': _companyName.text.trim(),
        'business_type': _businessType.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'gstin': _gstin.text.trim(),
        'address': _address.text.trim(),
        'state': _state.text.trim(),
        'bank_name': _bankName.text.trim(),
        'bank_account': _bankAccount.text.trim(),
        'ifsc': _ifsc.text.trim(),
        'invoice_prefix': _invoicePrefix.text.trim(),
        'default_gst': double.tryParse(_defaultGst.text.trim()),
        'currency': _currency.text.trim(),
        'round_total': _roundTotal,
      });
      _snack('Billing settings saved ✅');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _section('Your business', [
                  TextField(controller: _companyName, decoration: _dec('Business name')),
                  const SizedBox(height: 10),
                  TextField(controller: _businessType, decoration: _dec('Business type')),
                  const SizedBox(height: 10),
                  TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _dec('Phone')),
                  const SizedBox(height: 10),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _dec('Billing email')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _gstin,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _dec('GSTIN'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _address, maxLines: 2, decoration: _dec('Address')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _state,
                    decoration: _dec('State (place of supply)', hint: 'Needed for CGST/SGST vs IGST'),
                  ),
                ]),
                _section('Invoice defaults', [
                  TextField(controller: _invoicePrefix, decoration: _dec('Invoice prefix *')),
                  const SizedBox(height: 8),
                  Text(
                    'Next invoice number: ${_nextNumber.isEmpty ? '-' : _nextNumber}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _defaultGst,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Default GST %'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _currency, decoration: _dec('Currency', hint: 'e.g. INR')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Round total to nearest rupee'),
                    value: _roundTotal,
                    onChanged: (v) => setState(() => _roundTotal = v),
                  ),
                ]),
                _section('Bank details', [
                  TextField(controller: _bankName, decoration: _dec('Bank name')),
                  const SizedBox(height: 10),
                  TextField(controller: _bankAccount, decoration: _dec('Account number')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ifsc,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _dec('IFSC code'),
                  ),
                ]),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save settings'),
                ),
              ],
            ),
    );
  }
}
