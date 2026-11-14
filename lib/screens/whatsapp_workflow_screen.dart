import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import 'whatsapp_bots_screen.dart' show workflowBadge;
import 'whatsapp_campaigns_screen.dart' show StatusBadge;

/// One automation: what starts it, whether it is on, and its run history.
/// The flow itself is edited on the web; here it can be switched on or off.
class WhatsAppWorkflowScreen extends StatefulWidget {
  const WhatsAppWorkflowScreen({super.key, required this.workflowId});

  final String workflowId;

  @override
  State<WhatsAppWorkflowScreen> createState() => _WhatsAppWorkflowScreenState();
}

class _WhatsAppWorkflowScreenState extends State<WhatsAppWorkflowScreen> {
  final _scroll = ScrollController();
  WaWorkflow? _flow;
  List<WaExecution> _runs = [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final flow = await WhatsAppService.workflow(widget.workflowId);
      final runs = await WhatsAppService.executions(widget.workflowId);
      if (!mounted) return;
      setState(() {
        _flow = flow;
        _runs = runs.items;
        _page = runs.page;
        _hasMore = runs.hasMore;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final res = await WhatsAppService.executions(
        widget.workflowId,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        final have = _runs.map((r) => r.id).toSet();
        _runs = [..._runs, ...res.items.where((r) => !have.contains(r.id))];
        _page = res.page;
        _hasMore = res.hasMore;
      });
    } catch (_) {
      // The next scroll tries again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(
    String title,
    String text,
    String action, {
    bool danger = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: bad) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _activate(WaWorkflow w) async {
    if (!await _confirm(
      'Turn on "${w.name}"?',
      'It starts running right away for ${w.triggerLabel.toLowerCase()}.',
      'Turn on',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final fresh = await WhatsAppService.activateWorkflow(w.id);
      if (mounted) setState(() => _flow = fresh);
      _snack('Automation is on.');
    } catch (e) {
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pause(WaWorkflow w) async {
    if (!await _confirm(
      'Pause "${w.name}"?',
      'It stops starting for new contacts. You can turn it on again later.',
      'Pause',
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      final fresh = await WhatsAppService.pauseWorkflow(w.id);
      if (mounted) setState(() => _flow = fresh);
      _snack('Automation paused.');
    } catch (e) {
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(WaWorkflow w) async {
    if (!await _confirm(
      'Delete this draft?',
      'The draft automation is removed.',
      'Delete',
      danger: true,
    )) {
      return;
    }
    setState(() => _busy = true);
    try {
      await WhatsAppService.deleteWorkflow(w.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack(errorLine(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _body(WaWorkflow w) {
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        w.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ink,
                        ),
                      ),
                    ),
                    workflowBadge(w.status),
                  ],
                ),
                if (w.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    w.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: muted,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Starts when',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                Text(
                  w.triggerLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    '${w.nodesCount} steps',
                    'ran ${w.executionsCount} ${w.executionsCount == 1 ? 'time' : 'times'}',
                    if (w.activatedAt != null)
                      'on since ${fmtDate(w.activatedAt!)}',
                  ].join(' · '),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.desktop_windows_outlined,
                        size: 16,
                        color: brand,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The steps of an automation are edited on the Eydia website.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
            child: Text(
              'Run history',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: ink,
              ),
            ),
          ),
          if (_runs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'It has not run yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: muted),
              ),
            ),
          for (final r in _runs)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        if (r.startedAt != null)
                          Text(
                            fmtDateTime(r.startedAt!),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    r.status.isEmpty
                        ? '—'
                        : r.status[0].toUpperCase() +
                              r.status.substring(1).replaceAll('_', ' '),
                    switch (r.status) {
                      'completed' => good,
                      'failed' => bad,
                      'running' || 'waiting' => brand,
                      _ => muted,
                    },
                  ),
                ],
              ),
            ),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _actions(WaWorkflow w) {
    final children = <Widget>[
      if (w.isActive)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _pause(w),
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pause'),
          ),
        ),
      if (w.canActivate)
        Expanded(
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _activate(w),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(w.status == 'paused' ? 'Turn on again' : 'Turn on'),
          ),
        ),
      if (w.canDelete)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _delete(w),
            style: OutlinedButton.styleFrom(foregroundColor: bad),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete draft'),
          ),
        ),
    ];
    if (children.isEmpty) return null;
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 10));
      spaced.add(children[i]);
    }
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(children: spaced),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _flow;
    final error = _error;
    Widget body;
    if (_loading) {
      body = const SkeletonList(count: 3, itemHeight: 70, headerHeight: 190);
    } else if (error != null && w == null) {
      final access = accessProblem(error);
      body = Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load this automation',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    } else {
      body = _body(w!);
    }
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Automation',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
      ),
      body: body,
      bottomNavigationBar: w == null ? null : _actions(w),
    );
  }
}
