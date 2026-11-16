import 'dart:async';

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
import '../widgets/wa_ui.dart';

/// One bulk send: progress, each number's result, and "Retry failed".
/// Refreshes itself while it is still sending.
class WhatsAppBulkDetailScreen extends StatefulWidget {
  const WhatsAppBulkDetailScreen({super.key, required this.bulkId});

  final String bulkId;

  @override
  State<WhatsAppBulkDetailScreen> createState() =>
      _WhatsAppBulkDetailScreenState();
}

class _WhatsAppBulkDetailScreenState extends State<WhatsAppBulkDetailScreen> {
  WaBulkSend? _send;
  bool _loading = true;
  bool _retrying = false;
  Object? _error;
  Timer? _poll;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_send?.processing == true && !_retrying) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final s = await WhatsAppService.bulkSend(widget.bulkId);
      if (!mounted) return;
      setState(() {
        _send = s;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _retry(WaBulkSend s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Retry ${s.failed} failed ${s.failed == 1 ? 'number' : 'numbers'}?',
        ),
        content: const Text(
          'Only the numbers that failed are sent again. The ones that went '
          'through are not repeated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _retrying = true);
    try {
      final fresh = await WhatsAppService.retryBulk(s.id);
      if (mounted) setState(() => _send = fresh);
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Widget _body(WaBulkSend s) {
    final shown = s.recipients
        .where((r) => _filter == 'all' || r.status == _filter)
        .toList();
    final hasRecipients = s.recipients.isNotEmpty;
    final emptyFilter = hasRecipients && shown.isEmpty;
    // Rows: the summary card, the filter chips, an "empty" note when a filter
    // matches nothing, then one row per number. A bulk send can have 1000
    // numbers, so the rows are built lazily as they scroll into view.
    final lead = 1 + (hasRecipients ? 1 : 0) + (emptyFilter ? 1 : 0);

    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: lead + shown.length,
        itemBuilder: (_, i) {
          if (i == 0) return _summary(s);
          if (i == 1 && hasRecipients) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final f in const [
                    ('all', 'All'),
                    ('failed', 'Failed'),
                    ('delivered', 'Delivered'),
                    ('pending', 'Waiting'),
                  ])
                    ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                    ),
                ],
              ),
            );
          }
          if (emptyFilter && i == lead - 1) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No numbers here.',
                  style: GoogleFonts.plusJakartaSans(color: muted),
                ),
              ),
            );
          }
          return _recipientRow(shown[i - lead]);
        },
      ),
    );
  }

  Widget _summary(WaBulkSend s) {
    // "Sent" in the bar means sent but not delivered yet: delivered ones are
    // already counted in the sent total.
    final sentOnly = s.sent > s.delivered ? s.sent - s.delivered : 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.template,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: ink,
                  ),
                ),
              ),
              s.processing
                  ? const StatusBadge('Sending', brand)
                  : const StatusBadge('Done', good),
            ],
          ),
          if (s.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                fmtDateTime(s.createdAt!),
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            bulkStory(s),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color: inkSoft,
              height: 1.4,
            ),
          ),
          if (s.total > 0) ...[
            const SizedBox(height: 14),
            StackedBar(
              total: s.total,
              segments: [
                BarSegment('Delivered', s.delivered, brand),
                BarSegment('Sent', sentOnly, const Color(0xFF9AA6C8)),
                BarSegment('Failed', s.failed, bad),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _recipientRow(WaBulkRecipient r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                if (r.error.isNotEmpty)
                  Text(
                    r.error,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: bad,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            r.status.isEmpty
                ? '—'
                : r.status == 'pending'
                ? 'Waiting'
                : r.status[0].toUpperCase() + r.status.substring(1),
            switch (r.status) {
              'failed' => bad,
              'sent' || 'delivered' || 'read' => good,
              _ => muted,
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _send;
    final error = _error;
    Widget body;
    if (_loading) {
      body = const SkeletonList(count: 4, itemHeight: 82, headerHeight: 130);
    } else if (error != null && s == null) {
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
                  title: 'Could not load this bulk send',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    } else {
      body = _body(s!);
    }
    final showRetry = s != null && !s.processing && s.failed > 0;
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Bulk send',
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
      bottomNavigationBar: !showRetry
          ? null
          : Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                10 + MediaQuery.paddingOf(context).bottom,
              ),
              child: FilledButton.icon(
                onPressed: _retrying ? null : () => _retry(s),
                icon: _retrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text('Retry ${s.failed} failed'),
              ),
            ),
    );
  }
}

/// One plain sentence about where a bulk send stands.
String bulkStory(WaBulkSend s) {
  if (s.processing) {
    return 'Sending now: ${s.done} of ${s.total} handled. This page updates '
        'by itself.';
  }
  if (s.failed > 0) {
    return 'Done. ${s.total - s.failed} of ${s.total} went out, ${s.failed} '
        'failed. You can retry only the failed ones.';
  }
  return 'Done. All ${s.total} were sent.';
}
