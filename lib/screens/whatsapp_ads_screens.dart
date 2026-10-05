import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/invoice_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

String _s(dynamic v) => v?.toString() ?? '';

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v)) ?? 0;
}

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String _date(dynamic v) {
  final t = _s(v);
  return t.length >= 10 ? t.substring(0, 10) : t;
}

InputDecoration _dec(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );

void _snackOn(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

// ---------- WhatsApp ----------

class WhatsappScreen extends StatefulWidget {
  const WhatsappScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<WhatsappScreen> createState() => _WhatsappScreenState();
}

class _WhatsappScreenState extends State<WhatsappScreen> {
  List<Map<String, dynamic>> _messages = [];
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
      final json = await ApiService.instance.getList('/whatsapp');
      if (mounted) setState(() => _messages = json.cast<Map<String, dynamic>>());
      if (mounted) setState(() => _error = null);
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

  Future<void> _compose() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _WhatsappSheet(),
    );
    if (result != null && mounted) {
      _snackOn(context, result == 'sent' ? 'Message sent ✅' : 'Saved as queued (WhatsApp not connected)');
    }
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_rounded),
        label: Text('New message', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: warn.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: warn.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Messages are sent through WhatsApp Cloud API. Use an approved template name. Plain text works only inside the 24-hour customer window.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading && _messages.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Text('😕 $_error')
            else if (_messages.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('💬  No messages yet. Send your first template message.')),
              )
            else
              for (final m in _messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _s(m['to_phone']),
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: muted.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _s(m['status']).isEmpty ? 'queued' : _s(m['status']),
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Template: ${_s(m['template'])}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: brand),
                        ),
                        if (_s(m['body']).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _s(m['body']),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _date(m['created_at']),
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _WhatsappSheet extends StatefulWidget {
  const _WhatsappSheet();

  @override
  State<_WhatsappSheet> createState() => _WhatsappSheetState();
}

class _WhatsappSheetState extends State<_WhatsappSheet> {
  final _phone = TextEditingController();
  final _template = TextEditingController(text: 'review_request');
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _template.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_phone.text.trim().isEmpty || _template.text.trim().isEmpty) {
      _snackOn(context, 'Phone and template are required');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/whatsapp', body: {
        'to_phone': _phone.text.trim(),
        'template': _template.text.trim(),
        if (_body.text.trim().isNotEmpty) 'body': _body.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(res['status']?.toString() ?? 'sent');
    } on ApiException catch (e) {
      if (mounted) _snackOn(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
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
            'New WhatsApp message',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: _dec('Phone (with country code) *', hint: 'e.g. 919876543210'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _template, decoration: _dec('Template name *')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 3, decoration: _dec('Message (optional)')),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Queue message'),
          ),
        ],
      ),
    );
  }
}

// ---------- Ads Reports ----------

class AdsReportsScreen extends StatefulWidget {
  const AdsReportsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AdsReportsScreen> createState() => _AdsReportsScreenState();
}

class _AdsReportsScreenState extends State<AdsReportsScreen> {
  Map<String, dynamic>? _data;
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
      final json = await ApiService.instance.get('/ads');
      if (mounted) setState(() => _data = json);
      if (mounted) setState(() => _error = null);
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

  Future<void> _addReport() async {
    final d = _data;
    final clients = ((d?['clients'] as List?) ?? []).cast<Map<String, dynamic>>();
    if (clients.isEmpty) {
      _snackOn(context, 'Add a client first');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _AdReportSheet(clients: clients.map(CustomerOption.fromJson).toList()),
    );
    if (saved == true) {
      if (mounted) _snackOn(context, 'Campaign report added ✅');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final totals = (d?['totals'] as Map<String, dynamic>?) ?? {};
    final reports = ((d?['reports'] as List?) ?? []).cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: d == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addReport,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_chart_rounded),
              label: Text('Add report', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_loading && d == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Text('😕 $_error')
            else if (d != null) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  _Tile('💰', 'Total spend', '₹${_d(totals['spend']).toStringAsFixed(2)}', brand),
                  _Tile('👆', 'Clicks', '${_i(totals['clicks'])}', good),
                  _Tile('✅', 'Conversions', '${_i(totals['conversions'])}', brandDeep),
                  _Tile('🎯', 'Leads', '${_i(totals['leads'])}', warn),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: cardDecoration(),
                child: Column(
                  children: [
                    _ConnLine(label: 'Google Ads', connected: d['has_google'] == true),
                    const SizedBox(height: 8),
                    _ConnLine(label: 'Meta Ads', connected: d['has_meta'] == true),
                    const SizedBox(height: 8),
                    Text(
                      'Connections are managed from the web app.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('📊  No campaigns yet. Add your first report.')),
                )
              else
                for (final r in reports)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _s(r['campaign']),
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                                ),
                              ),
                              Text(
                                _s(r['network']),
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: brand),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_date(r['period_start'])} → ${_date(r['period_end'])}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Spend ₹${_d(r['spend']).toStringAsFixed(2)}  •  Clicks ${_i(r['clicks'])}  •  '
                            'Impr. ${_i(r['impressions'])}  •  Conv. ${_i(r['conversions'])}  •  Leads ${_i(r['leads'])}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.emoji, this.label, this.value, this.color);

  final String emoji;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: color),
          ),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: muted)),
        ],
      ),
    );
  }
}

class _ConnLine extends StatelessWidget {
  const _ConnLine({required this.label, required this.connected});

  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(connected ? Icons.check_circle_rounded : Icons.link_off_rounded,
            color: connected ? good : warn, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink)),
        ),
        Text(
          connected ? 'Connected' : 'Not connected',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: connected ? good : muted),
        ),
      ],
    );
  }
}

class _AdReportSheet extends StatefulWidget {
  const _AdReportSheet({required this.clients});

  final List<CustomerOption> clients;

  @override
  State<_AdReportSheet> createState() => _AdReportSheetState();
}

class _AdReportSheetState extends State<_AdReportSheet> {
  late int _clientId = widget.clients.first.id;
  String _network = 'GOOGLE';
  final _campaign = TextEditingController();
  final _spend = TextEditingController();
  final _clicks = TextEditingController();
  final _impressions = TextEditingController();
  final _conversions = TextEditingController();
  final _leads = TextEditingController();
  late DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  late DateTime _end = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_campaign, _spend, _clicks, _impressions, _conversions, _leads]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    if (_campaign.text.trim().isEmpty) {
      _snackOn(context, 'Campaign name is required');
      return;
    }
    if (_end.isBefore(_start)) {
      _snackOn(context, 'End date must be after start date');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.instance.post('/ads', body: {
        'client_id': _clientId,
        'network': _network,
        'campaign': _campaign.text.trim(),
        'spend': double.tryParse(_spend.text.trim()) ?? 0,
        'clicks': int.tryParse(_clicks.text.trim()) ?? 0,
        'impressions': int.tryParse(_impressions.text.trim()) ?? 0,
        'conversions': int.tryParse(_conversions.text.trim()) ?? 0,
        'leads': int.tryParse(_leads.text.trim()) ?? 0,
        'period_start': _fmt(_start),
        'period_end': _fmt(_end),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) _snackOn(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
              'Add campaign report',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _clientId,
              decoration: _dec('Client'),
              items: [for (final c in widget.clients) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _clientId = v ?? _clientId),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'GOOGLE', label: Text('Google Ads')),
                ButtonSegment(value: 'META', label: Text('Meta Ads')),
              ],
              selected: {_network},
              onSelectionChanged: (s) => setState(() => _network = s.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: _campaign, decoration: _dec('Campaign name *')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _spend,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Spend (₹)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _clicks,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Clicks'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _impressions,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Impressions'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _conversions,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Conversions'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: _leads, keyboardType: TextInputType.number, decoration: _dec('Leads')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(start: true),
                    child: Text('From ${_fmt(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(start: false),
                    child: Text('To ${_fmt(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save report'),
            ),
          ],
        ),
      ),
    );
  }
}
