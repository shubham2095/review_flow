import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_media_models.dart' show aiMediaBytes;
import '../models/invoicing_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/invoicing_service.dart';
import '../theme/brand.dart';
import '../widgets/invoice_format.dart';
import '../widgets/offline_banner.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';

/// Currencies offered for invoices. A currency already saved on the server
/// that is not here is still shown.
const invoiceCurrencies = [
  'INR',
  'USD',
  'EUR',
  'GBP',
  'AUD',
  'CAD',
  'SGD',
  'AED',
];

/// What is wrong with the business details, or null.
String? invoiceProfileProblem({
  required String prefix,
  required String gstText,
  required String email,
}) {
  final p = prefix.trim();
  if (p.isEmpty) return 'Write the prefix for invoice numbers, such as INV.';
  if (p.length > 10) return 'Keep the prefix to 10 characters or fewer.';
  final gst = double.tryParse(gstText.trim().replaceAll(',', '.'));
  if (gst == null || gst < 0 || gst > 100) {
    return 'Usual GST must be a number from 0 to 100.';
  }
  final e = email.trim();
  if (e.isNotEmpty && (!e.contains('@') || !e.contains('.'))) {
    return 'That email address does not look right.';
  }
  return null;
}

/// The business details printed on every invoice: who you are, how to pay
/// you, how invoices are numbered, the usual GST and the currency. Pops with
/// true when something was saved.
class InvoiceProfileScreen extends StatefulWidget {
  const InvoiceProfileScreen({super.key});

  @override
  State<InvoiceProfileScreen> createState() => _InvoiceProfileScreenState();
}

class _InvoiceProfileScreenState extends State<InvoiceProfileScreen> {
  InvoiceProfile? _profile;
  final _company = TextEditingController();
  final _type = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _state = TextEditingController();
  final _bank = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  final _prefix = TextEditingController();
  final _gst = TextEditingController();
  String _currency = 'INR';
  bool _round = false;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _saved = false;
  Object? _error;
  String? _notice;

  List<TextEditingController> get _all => [
    _company,
    _type,
    _phone,
    _email,
    _gstin,
    _address,
    _state,
    _bank,
    _account,
    _ifsc,
    _prefix,
    _gst,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(InvoiceProfile p) {
    _company.text = p.companyName;
    _type.text = p.businessType;
    _phone.text = p.phone;
    _email.text = p.email;
    _gstin.text = p.gstin;
    _address.text = p.address;
    _state.text = p.state;
    _bank.text = p.bankName;
    _account.text = p.bankAccount;
    _ifsc.text = p.ifsc;
    _prefix.text = p.invoicePrefix;
    _gst.text = invoiceNumber(p.defaultGst);
    _currency = p.currency;
    _round = p.roundTotal;
  }

  Future<void> _load() async {
    try {
      final p = await InvoicingService.profile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _fill(p);
        _dirty = false;
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

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (_saving) return;
    final problem = invoiceProfileProblem(
      prefix: _prefix.text,
      gstText: _gst.text,
      email: _email.text,
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
      final saved = await InvoicingService.saveProfile(
        InvoiceProfile(
          companyName: _company.text.trim(),
          businessType: _type.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          gstin: _gstin.text.trim(),
          address: _address.text.trim(),
          state: _state.text.trim(),
          bankName: _bank.text.trim(),
          bankAccount: _account.text.trim(),
          ifsc: _ifsc.text.trim(),
          invoicePrefix: _prefix.text.trim(),
          defaultGst: double.parse(_gst.text.trim().replaceAll(',', '.')),
          currency: _currency,
          roundTotal: _round,
        ),
      );
      if (!mounted) return;
      _saved = true;
      setState(() {
        _profile = saved;
        _fill(saved);
        _dirty = false;
        _saving = false;
      });
      showToast(context, 'Business details saved.');
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
        title: const Text('Leave without saving?'),
        content: const Text('Your changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop(_saved);
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    int? maxLength,
    int maxLines = 1,
    String? helper,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: !_saving,
        keyboardType: keyboard,
        textCapitalization: caps,
        maxLength: maxLength,
        minLines: 1,
        maxLines: maxLines,
        onChanged: (_) => _touch(),
        decoration: waInputDecoration(
          label,
          helper: helper,
          hint: hint,
          onWhite: false,
        ),
      ),
    );
  }

  Widget _form(InvoiceProfile p) {
    final currencies = {
      ...invoiceCurrencies,
      if (_currency.isNotEmpty) _currency,
    }.toList();
    final logo = aiMediaBytes(p.logo);
    final next = nextInvoiceNumber(
      _prefix.text.trim().isEmpty ? 'INV' : _prefix.text.trim(),
      p.nextNumber,
    );
    return Column(
      children: [
        Expanded(
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const SectionTitle(
                  'Your business',
                  padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
                ),
                if (logo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            logo,
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                            semanticLabel: 'Your logo',
                            errorBuilder: (_, _, _) =>
                                const SizedBox(width: 56, height: 56),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'The logo on your invoices. Change it on the Eydia '
                            'website.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _field(
                  'Business name',
                  _company,
                  caps: TextCapitalization.words,
                  maxLength: 255,
                ),
                _field(
                  'Type of business (optional)',
                  _type,
                  caps: TextCapitalization.words,
                  maxLength: 60,
                ),
                _field(
                  'Phone',
                  _phone,
                  keyboard: TextInputType.phone,
                  maxLength: 30,
                ),
                _field(
                  'Email',
                  _email,
                  keyboard: TextInputType.emailAddress,
                  maxLength: 255,
                ),
                _field(
                  'GSTIN',
                  _gstin,
                  caps: TextCapitalization.characters,
                  maxLength: 20,
                ),
                _field(
                  'Address',
                  _address,
                  caps: TextCapitalization.sentences,
                  maxLength: 500,
                  maxLines: 3,
                ),
                _field(
                  'State',
                  _state,
                  caps: TextCapitalization.words,
                  maxLength: 60,
                ),
                const SectionTitle(
                  'How to pay you',
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 12),
                ),
                _field(
                  'Bank name',
                  _bank,
                  caps: TextCapitalization.words,
                  maxLength: 255,
                ),
                _field(
                  'Account number',
                  _account,
                  keyboard: TextInputType.number,
                  maxLength: 50,
                ),
                _field(
                  'IFSC',
                  _ifsc,
                  caps: TextCapitalization.characters,
                  maxLength: 20,
                ),
                const SectionTitle(
                  'Invoices',
                  padding: EdgeInsets.fromLTRB(4, 12, 4, 12),
                ),
                _field(
                  'Invoice number prefix',
                  _prefix,
                  caps: TextCapitalization.characters,
                  maxLength: 10,
                  helper: 'The next invoice will be $next.',
                ),
                _field(
                  'Usual GST %',
                  _gst,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: 'Used for a line that has no GST of its own.',
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: waInputDecoration('Currency', onWhite: false),
                    items: [
                      for (final c in currencies)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) {
                            setState(() => _currency = v ?? _currency);
                            _touch();
                          },
                  ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Round the total'),
                  subtitle: const Text(
                    'Round each invoice total to a whole amount',
                  ),
                  value: _round,
                  onChanged: _saving
                      ? null
                      : (v) {
                          setState(() => _round = v);
                          _touch();
                        },
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
            10,
            16,
            10 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetNotice(_notice),
              FilledButton(
                onPressed: _saving || !_dirty ? null : _save,
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
                    : const Text('Save details'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 82, headerHeight: 60);
    }
    final error = _error;
    final p = _profile;
    if (error != null && p == null) {
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
                  title: 'Could not load your business details',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    return _form(p!);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dirty && !_saving) {
          _confirmLeave();
        } else {
          Navigator.of(context).pop(_saved);
        }
      },
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          title: Text(
            'Business details',
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
