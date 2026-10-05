import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TallyScreen extends StatefulWidget {
  const TallyScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<TallyScreen> createState() => _TallyScreenState();
}

class _TallyScreenState extends State<TallyScreen> {
  Map<String, dynamic>? _summary;
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _to = DateTime.now();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await ApiService.instance.get('/tally-export');
      if (mounted) setState(() => _summary = json);
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _download() async {
    if (_from.isAfter(_to)) {
      _snack('"From" date must be before "To" date');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await ApiService.instance.getBytes(
        '/tally-export/download?from=${_fmt(_from)}&to=${_fmt(_to)}',
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tally-export-${_fmt(_from)}-to-${_fmt(_to)}.xml');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'text/xml')], subject: 'Tally export'),
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final count = (s?['invoice_count'] as num?)?.toInt() ?? 0;
    final stateSet = _s(s?['state']).isNotEmpty;

    return Scaffold(
      backgroundColor: surface,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export invoices to TallyPrime',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                  const SizedBox(height: 6),
                  Text(
                    'Only SENT, PAID and OVERDUE invoices are exported. Drafts are never exported.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 12),
                  Text('Invoices available in the app: $count',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink)),
                  Text('Company in Tally: ${_s(s?['tally_company_name']).isEmpty ? _s(s?['company_name']) : _s(s?['tally_company_name'])}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted)),
                ],
              ),
            ),
            if (!stateSet)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: bad.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                child: Text(
                  'Your business state is not set. Set it in Billing settings, otherwise GST cannot be split into CGST/SGST or IGST.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: bad),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(from: true),
                    child: Text('From ${_fmt(_from)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pick(from: false),
                    child: Text('To ${_fmt(_to)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _download,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded),
              label: const Text('Download Tally XML'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(),
              child: Text(
                'How to import: open TallyPrime, go to Gateway of Tally → Import Data → Vouchers, then select the downloaded .xml file.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _s(dynamic v) => v?.toString() ?? '';
