import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/invoice_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/health_ring.dart';
import 'ai_more_screens.dart';

class _Tool {
  const _Tool(this.emoji, this.title, this.subtitle, this.builder);

  final String emoji;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

class AiToolsScreen extends StatelessWidget {
  const AiToolsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context) {
    final tools = [
      _Tool('⚡', 'One-Click Optimize', 'Profile score and AI fixes',
          (_) => OptimizeScreen(onSignedOut: onSignedOut)),
      _Tool('🔍', 'Google Audit', 'Audit a client\'s profile with AI tips',
          (_) => AuditScreen(onSignedOut: onSignedOut)),
      _Tool('🔑', 'Keywords', 'Local SEO keyword ideas',
          (_) => KeywordsScreen(onSignedOut: onSignedOut)),
      _Tool('📍', 'Rank Checker', 'See where you rank for a keyword',
          (_) => RankCheckerScreen(onSignedOut: onSignedOut)),
      _Tool('⚔️', 'Competitors', 'Compare with local competitors',
          (_) => CompetitorScreen(onSignedOut: onSignedOut)),
      _Tool('💬', 'AI Mode', 'Ask the marketing assistant',
          (_) => AiChatScreen(onSignedOut: onSignedOut)),
    ];

    return Scaffold(
      backgroundColor: surface,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(),
            child: Text(
              'AI tools use credits. Your balance is shown on the web app.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
            ),
          ),
          const SizedBox(height: 14),
          for (final t in tools)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: t.builder)),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardDecoration(),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [brand, brandDeep]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(t.emoji, style: const TextStyle(fontSize: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink)),
                              const SizedBox(height: 2),
                              Text(t.subtitle,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared page scaffold for AI tool screens.
class ToolPage extends StatelessWidget {
  const ToolPage({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [child],
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: ink)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class BulletList extends StatelessWidget {
  const BulletList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '•  $i',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink, height: 1.4),
            ),
          ),
      ],
    );
  }
}

void showToolError(BuildContext context, Object e) {
  final text = e is ApiException ? e.message : friendlyException(e).message;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

// ---------- One-Click Optimize ----------

class OptimizeScreen extends StatefulWidget {
  const OptimizeScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<OptimizeScreen> createState() => _OptimizeScreenState();
}

class _OptimizeScreenState extends State<OptimizeScreen> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _actions = [];
  bool _loading = true;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await ApiService.instance.get('/optimization');
      if (mounted) setState(() => _data = json);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final res = await ApiService.instance.post('/optimization/run');
      if (mounted) {
        setState(() => _actions = ((res['actions'] as List?) ?? []).cast<Map<String, dynamic>>());
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Color _catColor(String name) {
    switch (name) {
      case 'amber':
        return star;
      case 'blue':
        return brand;
      case 'green':
        return good;
      case 'purple':
        return brandDeep;
      case 'rose':
        return bad;
      default:
        return muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return ToolPage(
      title: 'One-Click Optimize',
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : d == null
              ? const Text('Could not load optimization data.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: HealthRing(score: num.tryParse((d['overall_score'])?.toString() ?? '')?.toInt() ?? 0, size: 150)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration(),
                      child: Column(
                        children: [
                          for (final c in (d['categories'] as List? ?? []).cast<Map<String, dynamic>>())
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c['label']?.toString() ?? '',
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
                                        ),
                                      ),
                                      Text(
                                        '${c['score']}%',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          color: _catColor(c['color']?.toString() ?? ''),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: (num.tryParse((c['score'])?.toString() ?? '')?.toDouble() ?? 0) / 100,
                                      minHeight: 8,
                                      color: _catColor(c['color']?.toString() ?? ''),
                                      backgroundColor: muted.withValues(alpha: 0.15),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _running ? null : _run,
                      icon: _running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bolt_rounded),
                      label: const Text('Run full optimization'),
                    ),
                    if (_actions.isNotEmpty)
                      ResultCard(
                        title: 'Actions taken',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final a in _actions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a['title']?.toString() ?? '',
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
                                    ),
                                    Text(
                                      a['detail']?.toString() ?? '',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

// ---------- Google Audit ----------

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<CustomerOption> _clients = [];
  int? _clientId;
  Map<String, dynamic>? _result;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final list = await ApiService.instance.getList('/invoicing/customers');
      if (!mounted) return;
      setState(() {
        _clients = list.cast<Map<String, dynamic>>().map(CustomerOption.fromJson).toList();
        if (_clients.isNotEmpty) _clientId = _clients.first.id;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run() async {
    if (_clientId == null) return;
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/audit', body: {'client_id': _clientId});
      if (mounted) setState(() => _result = res);
    } on ApiException catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final tips = (r?['ai_tips'] ?? '').toString();
    return ToolPage(
      title: 'Google Audit',
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : _clients.isEmpty
              ? const Text('Add a client first to run an audit.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _clientId,
                      decoration: InputDecoration(
                        labelText: 'Client',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        for (final c in _clients) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _run,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.analytics_rounded),
                      label: const Text('Analyze profile'),
                    ),
                    if (r != null) ...[
                      ResultCard(
                        title: 'Audit score',
                        child: Column(
                          children: [
                            Center(child: HealthRing(score: num.tryParse((r['score'])?.toString() ?? '')?.toInt() ?? 0, size: 130)),
                            const SizedBox(height: 6),
                            Text(
                              r['grade']?.toString() ?? '',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                            ),
                          ],
                        ),
                      ),
                      ResultCard(
                        title: 'Checks',
                        child: Column(
                          children: [
                            for (final c in (r['checks'] as List? ?? []).cast<Map<String, dynamic>>())
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      c['ok'] == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                      color: c['ok'] == true ? good : warn,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['label']?.toString() ?? '',
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
                                          ),
                                          Text(
                                            c['note']?.toString() ?? '',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (tips.isNotEmpty)
                        ResultCard(
                          title: 'AI tips',
                          child: Text(
                            tips,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink, height: 1.5),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}
