import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';

/// Platform settings: seller details printed on invoices, and the AI provider.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.receipt_long_rounded),
                    label: Text('Invoice details'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.auto_awesome_rounded),
                    label: Text('AI provider'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [_InvoiceTab(), _AiTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- Invoice details

class _InvoiceTab extends StatefulWidget {
  const _InvoiceTab();

  @override
  State<_InvoiceTab> createState() => _InvoiceTabState();
}

class _InvoiceTabState extends State<_InvoiceTab> {
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _gstin = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _tax = TextEditingController();
  final _prefix = TextEditingController();
  final _gst = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<TextEditingController> get _all =>
      [_company, _address, _gstin, _email, _phone, _tax, _prefix, _gst];

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

  void _fill(InvoiceSettings s) {
    _company.text = s.companyName;
    _address.text = s.address;
    _gstin.text = s.gstin;
    _email.text = s.email;
    _phone.text = s.phone;
    _tax.text = s.taxDetails;
    _prefix.text = s.invoicePrefix;
    _gst.text = '${s.gstRate}';
  }

  Future<void> _load() async {
    try {
      final s = await AdminService.invoiceSettings();
      if (!mounted) return;
      setState(() {
        _fill(s);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final gst = int.tryParse(_gst.text.trim());
    if (gst == null || gst < 0 || gst > 100) {
      _message('GST rate must be between 0 and 100.');
      return;
    }
    setState(() => _saving = true);
    try {
      String? blank(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      final s = await AdminService.saveInvoiceSettings({
        'company_name': blank(_company),
        'address': blank(_address),
        'gstin': blank(_gstin),
        'email': blank(_email),
        'phone': blank(_phone),
        'tax_details': blank(_tax),
        'invoice_prefix': blank(_prefix),
        'gst_rate': gst,
      });
      if (!mounted) return;
      setState(() => _fill(s));
      _message('Settings saved');
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? type, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        minLines: 1,
        maxLines: lines,
        decoration: adminInput(label).copyWith(fillColor: surface),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return SingleChildScrollView(
        child: AdminMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load settings',
          text: _error!,
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Printed on every invoice',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 12),
              _field(_company, 'Company name'),
              _field(_address, 'Address', lines: 3),
              _field(_gstin, 'GSTIN'),
              _field(_email, 'Email', type: TextInputType.emailAddress),
              _field(_phone, 'Phone', type: TextInputType.phone),
              _field(_tax, 'Tax details'),
              Row(
                children: [
                  Expanded(child: _field(_prefix, 'Invoice prefix')),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_gst, 'GST %', type: TextInputType.number)),
                ],
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- AI provider

class _AiTab extends StatefulWidget {
  const _AiTab();

  @override
  State<_AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<_AiTab> {
  AiSettingsData? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _active = false;
  String? _provider;
  final Map<String, TextEditingController> _keys = {};
  final Map<String, TextEditingController> _models = {};
  final _imageModel = TextEditingController();
  String? _testing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._keys.values, ..._models.values, _imageModel]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(AiSettingsData d) {
    _data = d;
    _active = d.isActive;
    _provider = d.activeProvider;
    for (final p in d.providers) {
      _keys.putIfAbsent(p.key, () => TextEditingController()).clear();
      _models.putIfAbsent(p.key, () => TextEditingController()).text = p.model;
    }
    _imageModel.text = d.geminiImageModel;
  }

  Future<void> _load() async {
    try {
      final d = await AdminService.aiSettings();
      if (!mounted) return;
      setState(() {
        _apply(d);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final d = _data;
    if (d == null) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'is_active': _active,
        'active_provider': _provider,
        'gemini_image_model': _imageModel.text.trim(),
        for (final p in d.providers) '${p.key}_model': _models[p.key]!.text.trim(),
        for (final p in d.providers)
          if (_keys[p.key]!.text.trim().isNotEmpty)
            '${p.key}_api_key': _keys[p.key]!.text.trim(),
      };
      final saved = await AdminService.saveAiSettings(body);
      if (!mounted) return;
      setState(() => _apply(saved));
      _message('AI provider settings saved');
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test(String provider) async {
    setState(() => _testing = provider);
    try {
      final r = await AdminService.testAiProvider(provider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            r.ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: r.ok ? good : bad,
          ),
          title: Text(r.ok ? 'Provider works' : 'Test failed'),
          content: Text(r.message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      _message(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _testing = null);
    }
  }

  String _name(String key) {
    switch (key) {
      case 'gemini':
        return 'Google Gemini';
      case 'anthropic':
        return 'Anthropic Claude';
      case 'openai':
        return 'OpenAI';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || d == null) {
      return SingleChildScrollView(
        child: AdminMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load AI settings',
          text: _error ?? '',
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Use the provider chosen here',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Off means the server .env keys are used'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              Text(
                d.effectiveProvider == null
                    ? 'Currently using: server .env keys'
                    : 'Currently using: ${_name(d.effectiveProvider!)}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 4),
              Text(
                d.canGenerateImages
                    ? 'Image generation is available.'
                    : 'Image generation needs a Gemini or OpenAI key.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in d.providers)
                    ChoiceChip(
                      label: Text(_name(p.key)),
                      selected: _provider == p.key,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _provider = p.key),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final p in d.providers)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _name(p.key),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ),
                    AdminBadge(
                      p.hasKey
                          ? (p.keySource == 'env' ? 'Key from .env' : 'Key saved')
                          : 'No key',
                      p.hasKey ? good : warn,
                    ),
                  ],
                ),
                if (p.hasKey && (p.keyLast4 ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Ends with ${p.keyLast4}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _models[p.key],
                  decoration: adminInput('Model', hint: p.modelDefault)
                      .copyWith(fillColor: surface),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keys[p.key],
                  obscureText: true,
                  decoration: adminInput(
                    'API key',
                    hint: p.hasKey ? 'Paste a new key to replace it' : 'Paste the key',
                  ).copyWith(fillColor: surface),
                ),
                if (p.key == 'gemini') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _imageModel,
                    decoration: adminInput('Image model').copyWith(fillColor: surface),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: (_testing != null || !p.hasKey) ? null : () => _test(p.key),
                    icon: _testing == p.key
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(p.hasKey ? 'Test this provider' : 'Save a key to test'),
                  ),
                ),
              ],
            ),
          ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save AI settings'),
        ),
      ],
    );
  }
}
