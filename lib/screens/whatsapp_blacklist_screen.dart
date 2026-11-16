import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';

/// Numbers that are never messaged: every send, campaigns included, skips them.
class WhatsAppBlacklistScreen extends StatefulWidget {
  const WhatsAppBlacklistScreen({super.key});

  @override
  State<WhatsAppBlacklistScreen> createState() =>
      _WhatsAppBlacklistScreenState();
}

class _WhatsAppBlacklistScreenState extends State<WhatsAppBlacklistScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<WaBlacklistEntry> _items = [];
  bool _loading = true;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() => _loading = true);
    _load();
  }

  Future<void> _load() async {
    final gen = ++_generation;
    try {
      final list = await WhatsAppService.blacklist(
        search: _search.text.trim(),
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    showToast(context, text);
  }

  Future<void> _add() async {
    final phone = TextEditingController();
    final reason = TextEditingController();
    String? problem;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Block a number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  errorText: problem,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (phone.text.replaceAll(RegExp(r'\D'), '').length < 8) {
                  setLocal(
                    () => problem = 'Enter the full number with country code.',
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Block'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await WhatsAppService.addToBlacklist(
        phone.text.trim(),
        reason: reason.text.trim(),
      );
      _snack('Number blocked.');
      _load();
    } catch (e) {
      _snack(errorLine(e));
    }
  }

  Future<void> _remove(WaBlacklistEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unblock ${e.phone}?'),
        content: const Text('This number can receive your messages again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await WhatsAppService.removeFromBlacklist(e.id);
      setState(() => _items = _items.where((x) => x.id != e.id).toList());
      _snack('Number unblocked.');
    } catch (err) {
      _snack(errorLine(err));
    }
  }

  Widget _body() {
    final error = _error;
    if (_loading) {
      return const SkeletonList(count: 5, itemHeight: 82, headerHeight: null);
    }
    if (error != null && _items.isEmpty) {
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
                  title: 'Could not load blocked numbers',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    }
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _search.text.trim().isNotEmpty
                    ? const StateView(
                        icon: Icons.search_off_rounded,
                        title: 'No blocked number matches',
                        text: 'Try a different name or number.',
                      )
                    : const StateView(
                        icon: Icons.block_rounded,
                        title: 'No blocked numbers',
                        text:
                            'Numbers you block here are skipped by every message you send. Use the button below to block one.',
                      ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final e = _items[i];
                return Semantics(
                  container: true,
                  label:
                      'Blocked: ${e.name.isEmpty ? e.phone : '${e.name}, ${e.phone}'}'
                      '${e.reason.isEmpty ? '' : ', ${e.reason}'}',
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                  decoration: cardDecoration(),
                  child: Row(
                    children: [
                      const ExcludeSemantics(
                        child: Icon(Icons.block_rounded, color: muted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name.isEmpty
                                  ? e.phone
                                  : '${e.name} · ${e.phone}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            Text(
                              [
                                if (e.reason.isNotEmpty) e.reason,
                                if (e.createdAt != null) fmtDate(e.createdAt!),
                              ].join(' · '),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Unblock ${e.phone}',
                        icon: const Icon(Icons.lock_open_rounded),
                        onPressed: () => _remove(e),
                      ),
                    ],
                  ),
                ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Blocked numbers',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Block a number'),
      ),
      body: ContentWidth(
        child: Column(
          children: [
            const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 450),
                    _restart,
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Search name or number',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            _restart();
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }
}
