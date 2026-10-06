import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

String _s(dynamic v) => v?.toString() ?? '';

int _i(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toInt() ?? 0;

String _date(dynamic v) {
  final t = _s(v);
  return t.length >= 10 ? t.substring(0, 10) : t;
}

String _label(String key) => key.replaceAll('_', ' ').toLowerCase();

/// Backend sends this month's usage as a list of rows; sum their credits.
int _usageTotal(dynamic v) {
  if (v is List) {
    return v.fold<int>(0, (sum, e) => sum + _i((e as Map)['total_credits']));
  }
  return _i(v);
}

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
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
      final json = await ApiService.instance.get('/billing/credits');
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

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final costs = ((d?['credit_costs'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), _i(v)));
    final ledger = ((d?['ledger'] as List?) ?? []).cast<Map<String, dynamic>>();

    return Scaffold(
      backgroundColor: surface,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_loading && d == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Text('😕 $_error')
            else if (d != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [brand, brandDeep]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI CREDITS BALANCE',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_i(d['balance'])}',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Monthly allowance: ${_i(d['monthly_credits'])}  •  Used this month: ${_usageTotal(d['usage_this_month'])}',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cost per action',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                    const SizedBox(height: 10),
                    for (final e in costs.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_label(e.key),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink)),
                            ),
                            Text('${e.value}',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: brand)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Recent activity',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
              const SizedBox(height: 8),
              if (ledger.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No credit activity yet.')),
                )
              else
                for (final l in ledger)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
                                  _label(_s(l['action'])),
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
                                ),
                                if (_s(l['description']).isNotEmpty)
                                  Text(
                                    _s(l['description']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
                                  ),
                                Text(
                                  _date(l['created_at']),
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: muted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_i(l['amount']) > 0 ? '+' : ''}${_i(l['amount'])}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  color: _i(l['amount']) >= 0 ? good : bad,
                                ),
                              ),
                              Text(
                                'Bal ${_i(l['balance_after'])}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'To buy credits or change your plan, use the web app (payments are handled there).',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
