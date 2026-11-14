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
import 'whatsapp_campaigns_screen.dart' show StatusBadge, campaignStatus;

/// One campaign: delivery numbers, who it went to, and Start, Pause, Cancel
/// or Delete depending on where it is. Refreshes itself while it is sending.
class WhatsAppCampaignDetailScreen extends StatefulWidget {
  const WhatsAppCampaignDetailScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  State<WhatsAppCampaignDetailScreen> createState() =>
      _WhatsAppCampaignDetailScreenState();
}

class _WhatsAppCampaignDetailScreenState
    extends State<WhatsAppCampaignDetailScreen> {
  WaCampaignDetail? _detail;
  bool _loading = true;
  bool _acting = false;
  Object? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_detail?.campaign.isRunning == true && !_acting) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final d = await WhatsAppService.campaign(widget.campaignId);
      if (!mounted) return;
      setState(() {
        _detail = d;
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

  Future<void> _act(Future<WaCampaign> Function() call, String done) async {
    setState(() => _acting = true);
    try {
      await call();
      _snack(done);
      await _load();
    } catch (e) {
      _snack(errorLine(e));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _start(WaCampaign c) async {
    final when = c.status == 'scheduled' && c.scheduledAt != null
        ? ' It was scheduled for ${fmtDateTime(c.scheduledAt!)}; this sends it now.'
        : '';
    if (!await _confirm(
      'Send to ${c.total} contacts?',
      'Template "${c.templateName}" goes out now to ${c.total} '
          'people. Messages cannot be recalled once sent.$when',
      'Start sending',
    )) {
      return;
    }
    await _act(() => WhatsAppService.startCampaign(c.id), 'Sending started.');
  }

  Future<void> _pause(WaCampaign c) async {
    if (!await _confirm(
      'Pause this campaign?',
      'Sending stops after the current message. Eydia cannot resume a paused '
          'campaign, so the people not reached yet will not get it. To send to '
          'them, create a new campaign.',
      'Pause',
    )) {
      return;
    }
    await _act(() => WhatsAppService.pauseCampaign(c.id), 'Campaign paused.');
  }

  Future<void> _cancel(WaCampaign c) async {
    if (!await _confirm(
      'Cancel this campaign?',
      'Sending stops for good. Messages already sent stay sent.',
      'Cancel campaign',
      danger: true,
    )) {
      return;
    }
    await _act(
      () => WhatsAppService.cancelCampaign(c.id),
      'Campaign cancelled.',
    );
  }

  Future<void> _delete(WaCampaign c) async {
    if (!await _confirm(
      'Delete this draft?',
      'The draft and its recipient list are removed.',
      'Delete',
      danger: true,
    )) {
      return;
    }
    setState(() => _acting = true);
    try {
      await WhatsAppService.deleteCampaign(c.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack(errorLine(e));
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _body(WaCampaignDetail d) {
    final c = d.campaign;
    final s = campaignStatus(c.status);
    final ratio = c.total == 0 ? 0.0 : (c.done / c.total).clamp(0.0, 1.0);
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ListView(
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
                        c.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: ink,
                        ),
                      ),
                    ),
                    StatusBadge(s.label, s.color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'Template ${c.templateName}',
                    if (c.numberLabel.isNotEmpty) 'from ${c.numberLabel}',
                  ].join(' · '),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
                if (c.status != 'draft') ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      color: s.color,
                      backgroundColor: const Color(0xFFEEF1F7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${c.done} of ${c.total} handled',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  [
                    if (c.scheduledAt != null &&
                        (c.status == 'scheduled' || c.status == 'draft'))
                      'Scheduled ${fmtDateTime(c.scheduledAt!)}',
                    if (c.startedAt != null)
                      'Started ${fmtDateTime(c.startedAt!)}',
                    if (c.completedAt != null)
                      'Finished ${fmtDateTime(c.completedAt!)}',
                    if (c.source.isNotEmpty) 'Audience: ${c.source} contacts',
                  ].join('\n'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _Stat('Recipients', c.total),
              _Stat('Sent', c.sent),
              _Stat('Delivered', c.delivered),
              _Stat('Read', c.read),
              _Stat('Replied', c.replied),
              _Stat('Failed', c.failed, color: c.failed > 0 ? bad : ink),
            ],
          ),
          if (d.recipients.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
              child: Text(
                d.totalRecipients > d.recipients.length
                    ? 'Recipients (first ${d.recipients.length} of ${d.totalRecipients})'
                    : 'Recipients',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ink,
                ),
              ),
            ),
            for (final r in d.recipients)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: cardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.name.trim().isEmpty
                            ? r.phone
                            : '${r.name} · ${r.phone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      r.status.isEmpty
                          ? '—'
                          : r.status[0].toUpperCase() + r.status.substring(1),
                      switch (r.status) {
                        'failed' => bad,
                        'sent' || 'delivered' || 'read' => good,
                        _ => muted,
                      },
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget? _actions(WaCampaign c) {
    final buttons = <Widget>[
      if (c.canStart)
        Expanded(
          child: FilledButton.icon(
            onPressed: _acting ? null : () => _start(c),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start sending'),
          ),
        ),
      if (c.isRunning)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _acting ? null : () => _pause(c),
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pause'),
          ),
        ),
      if (c.canCancel && !c.canDelete)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _acting ? null : () => _cancel(c),
            style: OutlinedButton.styleFrom(foregroundColor: bad),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Cancel'),
          ),
        ),
      if (c.canDelete)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _acting ? null : () => _delete(c),
            style: OutlinedButton.styleFrom(foregroundColor: bad),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete draft'),
          ),
        ),
    ];
    if (buttons.isEmpty) return null;
    // Two buttons sit side by side with a gap between them.
    final spaced = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 10));
      spaced.add(buttons[i]);
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
    final d = _detail;
    final error = _error;
    Widget body;
    if (_loading) {
      body = const SkeletonList(count: 3, itemHeight: 90, headerHeight: 150);
    } else if (error != null && d == null) {
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
                  title: 'Could not load this campaign',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
        ),
      );
    } else {
      body = _body(d!);
    }
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(
          'Campaign',
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
      bottomNavigationBar: d == null ? null : _actions(d.campaign),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color = ink});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
          ),
        ],
      ),
    );
  }
}
