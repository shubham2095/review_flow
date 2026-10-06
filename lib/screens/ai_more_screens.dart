import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/invoice_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import 'ai_tools_screen.dart';

// ---------- Keywords ----------

class KeywordsScreen extends StatefulWidget {
  const KeywordsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<KeywordsScreen> createState() => _KeywordsScreenState();
}

class _KeywordsScreenState extends State<KeywordsScreen> {
  final _business = TextEditingController();
  final _city = TextEditingController();
  final _industry = TextEditingController();
  List<Map<String, dynamic>> _groups = [];
  bool _busy = false;

  @override
  void dispose() {
    _business.dispose();
    _city.dispose();
    _industry.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_business.text.trim().isEmpty || _city.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business name and city are required')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/keywords', body: {
        'business': _business.text.trim(),
        'city': _city.text.trim(),
        if (_industry.text.trim().isNotEmpty) 'industry': _industry.text.trim(),
      });
      if (mounted) {
        setState(() => _groups = ((res['groups'] as List?) ?? []).cast<Map<String, dynamic>>());
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Keywords',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _business, decoration: _dec('Business name *')),
          const SizedBox(height: 10),
          TextField(controller: _city, decoration: _dec('City *')),
          const SizedBox(height: 10),
          TextField(controller: _industry, decoration: _dec('Industry (optional)')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _generate,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Generate keywords'),
          ),
          for (final g in _groups)
            ResultCard(
              title: g['group']?.toString() ?? '',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in (g['keywords'] as List? ?? []).map((e) => e.toString()))
                    ActionChip(
                      label: Text(k),
                      avatar: const Icon(Icons.copy_rounded, size: 14),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: k));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied: $k')),
                        );
                      },
                    ),
                ],
              ),
            ),
          if (_groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tap a keyword to copy it.',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Rank Checker ----------

class RankCheckerScreen extends StatefulWidget {
  const RankCheckerScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<RankCheckerScreen> createState() => _RankCheckerScreenState();
}

class _RankCheckerScreenState extends State<RankCheckerScreen> {
  List<Map<String, dynamic>> _locations = [];
  int? _locationId;
  final _keyword = TextEditingController();
  int _radius = 5;
  Map<String, dynamic>? _result;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final list = await ApiService.instance.getList('/reviews');
      if (!mounted) return;
      setState(() {
        _locations = list.cast<Map<String, dynamic>>();
        if (_locations.isNotEmpty) _locationId = num.tryParse((_locations.first['id'])?.toString() ?? '')?.toInt();
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

  Future<void> _check() async {
    if (_locationId == null || _keyword.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a location and enter a keyword')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/rank-checker', body: {
        'location_id': _locationId,
        'keyword': _keyword.text.trim(),
        'radius_km': _radius,
      });
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
    final rank = r?['rank'];
    final isUnavailable = r?['source'] == 'fallback';
    final results = ((r?['results'] as List?) ?? []).cast<Map<String, dynamic>>();

    return ToolPage(
      title: 'Rank Checker',
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _locationId,
                  decoration: InputDecoration(
                    labelText: 'Your business',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  items: [
                    for (final l in _locations)
                      DropdownMenuItem(
                        value: num.tryParse((l['id'])?.toString() ?? '')?.toInt(),
                        child: Text(l['title']?.toString() ?? 'Location'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _locationId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _keyword,
                  decoration: InputDecoration(
                    labelText: 'Search keyword (e.g. dentist)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final km in const [2, 5, 10, 20])
                      ChoiceChip(
                        label: Text('$km km'),
                        selected: _radius == km,
                        onSelected: (_) => setState(() => _radius = km),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _check,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.travel_explore_rounded),
                  label: const Text('Check ranking'),
                ),
                if (r != null)
                  ResultCard(
                    // The server sends a setup note (not for end users) when no ranking source is configured.
                    title: rank != null
                        ? 'Rank #$rank'
                        : isUnavailable
                            ? 'Ranking not available right now'
                            : 'Estimated rank: ${r['estimated_rank'] ?? 'Unknown'}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isUnavailable)
                          Text(
                            'We could not run a ranking check right now. Try again later. These steps usually help local rankings:',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink, height: 1.5),
                          )
                        else if ((r['summary']?.toString() ?? '').isNotEmpty)
                          Text(
                            r['summary'].toString(),
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink, height: 1.5),
                          ),
                        if (results.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Top results',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink)),
                          const SizedBox(height: 6),
                          for (var i = 0; i < results.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${i + 1}. ${results[i]['name'] ?? results[i]['title'] ?? 'Business'}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                              ),
                            ),
                        ],
                        if (((r['tips'] as List?) ?? []).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Tips',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink)),
                          const SizedBox(height: 6),
                          BulletList(items: (r['tips'] as List).map((e) => e.toString()).toList()),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------- Competitors ----------

class CompetitorScreen extends StatefulWidget {
  const CompetitorScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<CompetitorScreen> createState() => _CompetitorScreenState();
}

class _CompetitorScreenState extends State<CompetitorScreen> {
  List<CustomerOption> _clients = [];
  int? _clientId;
  final _competitors = TextEditingController();
  final _city = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _competitors.dispose();
    _city.dispose();
    super.dispose();
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
    if (_clientId == null || _competitors.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a client and enter competitor names')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ApiService.instance.post('/competitors', body: {
        'client_id': _clientId,
        'competitors': _competitors.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
      });
      if (mounted) setState(() => _result = res);
    } on ApiException catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> _list(dynamic v) => ((v as List?) ?? []).map((e) => e.toString()).toList();

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ToolPage(
      title: 'Competitors',
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : _clients.isEmpty
              ? const Text('Add a client first.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _clientId,
                      decoration: InputDecoration(
                        labelText: 'Your client',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: [
                        for (final c in _clients) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _competitors,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Competitors (comma separated)',
                        hintText: 'e.g. Smile Care Dental, City Dental Clinic',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _city,
                      decoration: InputDecoration(
                        labelText: 'City (optional)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
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
                          : const Icon(Icons.compare_arrows_rounded),
                      label: const Text('Analyze competitors'),
                    ),
                    if (r != null) ...[
                      ResultCard(
                        title: 'Overview',
                        child: Text(
                          r['summary']?.toString() ?? '',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ink, height: 1.5),
                        ),
                      ),
                      ResultCard(title: '💪 Strengths', child: BulletList(items: _list(r['strengths']))),
                      ResultCard(title: '⚠️ Gaps', child: BulletList(items: _list(r['gaps']))),
                      ResultCard(title: '🎯 Actions', child: BulletList(items: _list(r['actions']))),
                    ],
                  ],
                ),
    );
  }
}

// ---------- AI Mode (chat) ----------

class _ChatMessage {
  _ChatMessage(this.text, {required this.fromUser});

  factory _ChatMessage.fromJson(Map<String, dynamic> j) =>
      _ChatMessage(j['text']?.toString() ?? '', fromUser: j['fromUser'] == true);

  final String text;
  final bool fromUser;

  Map<String, dynamic> toJson() => {'text': text, 'fromUser': fromUser};
}

const _chatHistoryKey = 'ai_mode_history';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatHistoryKey);
      if (raw == null || !mounted) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() => _messages.addAll(list.map(_ChatMessage.fromJson)));
      _jumpToEnd();
    } catch (_) {
      // Corrupt history ko ignore karte hain, chat khaali se shuru hogi.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatHistoryKey, jsonEncode(_messages.map((m) => m.toJson()).toList()));
    } catch (_) {
      // Save fail hone par chat chalti rahegi, sirf history save nahi hogi.
    }
  }

  Future<void> _clear() async {
    setState(_messages.clear);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatHistoryKey);
    } catch (_) {}
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _messages.add(_ChatMessage(text, fromUser: true));
      _busy = true;
      _input.clear();
    });
    _jumpToEnd();
    try {
      final res = await ApiService.instance.post('/ai-mode', body: {'message': text});
      if (mounted) setState(() => _messages.add(_ChatMessage(res['reply']?.toString() ?? '', fromUser: false)));
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthService.logout();
        widget.onSignedOut();
        return;
      }
      if (mounted) setState(() => _messages.add(_ChatMessage(e.message, fromUser: false)));
    } finally {
      if (mounted) setState(() => _busy = false);
      await _persist();
      _jumpToEnd();
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'Write a reply to a 5-star review',
      'How do I get more Google reviews?',
      '5 local SEO tips for my business',
    ];

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        title: Text('AI Mode', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear chat',
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'How can I help you today?',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final s in suggestions)
                              ActionChip(label: Text(s), onPressed: () => _send(s)),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return Align(
                        alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                          decoration: BoxDecoration(
                            color: m.fromUser ? brand : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            m.text,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              height: 1.4,
                              color: m.fromUser ? Colors.white : ink,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask anything about marketing…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
