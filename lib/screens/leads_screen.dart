import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lead_models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  LeadBoard? _board;
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
      final json = await ApiService.instance.get('/leads');
      if (!mounted) return;
      setState(() {
        _board = LeadBoard.fromJson(json);
        _error = null;
      });
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openLead(LeadItem lead) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _LeadSheet(lead: lead, stages: _board!.stages),
    );
    if (result == 'moved') _snack('Lead stage updated ✅');
    if (result == 'deleted') _snack('Lead deleted 🗑️');
    if (result != null) _load();
  }

  Future<void> _addLead() async {
    final board = _board;
    if (board == null || board.clients.isEmpty) {
      _snack('Add a client first');
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddLeadSheet(clients: board.clients),
    );
    if (result == 'added') {
      _snack('New lead added 🎯');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;

    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: board == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addLead,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                'New lead',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: board == null
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: Center(
                      child: _loading
                          ? const CircularProgressIndicator()
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('😕', style: TextStyle(fontSize: 40)),
                                  const SizedBox(height: 8),
                                  Text(_error ?? 'Could not load leads', textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  FilledButton(onPressed: _load, child: const Text('Try again')),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) => ListView(
                  children: [
                    SizedBox(
                      height: constraints.maxHeight,
                      child: _Board(board: board, onLeadTap: _openLead),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.board, required this.onLeadTap});

  final LeadBoard board;
  final ValueChanged<LeadItem> onLeadTap;

  @override
  Widget build(BuildContext context) {
    final total = board.leads.length;
    final converted = board.leads.where((l) => l.stage == 'CONVERTED').length;
    final newCount = board.leads.where((l) => l.stage == 'NEW').length;
    final rate = total == 0 ? 0 : (converted * 100 / total).round();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: FadeIn(
            child: Row(
              children: [
                _StatTile(emoji: '🎯', value: total.toDouble(), label: 'Total', color: brand),
                const SizedBox(width: 8),
                _StatTile(emoji: '🆕', value: newCount.toDouble(), label: 'New', color: stageColors['NEW']!),
                const SizedBox(width: 8),
                _StatTile(emoji: '🎉', value: converted.toDouble(), label: 'Converted', color: good),
                const SizedBox(width: 8),
                _StatTile(emoji: '📈', value: rate.toDouble(), suffix: '%', label: 'Conversion', color: star),
              ],
            ),
          ),
        ),
        Expanded(
          child: total == 0
              ? FadeIn(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📭', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text(
                            'No leads yet',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "New lead" to add your first one.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: board.stages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final stage = board.stages[i];
                    final items = board.leads.where((l) => l.stage == stage).toList();
                    return FadeIn(
                      delay: i * 90,
                      child: _StageColumn(
                        stage: stage,
                        leads: items,
                        onLeadTap: onLeadTap,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
    this.suffix = '',
  });

  final String emoji;
  final double value;
  final String suffix;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(
                  '${v.round()}$suffix',
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, color: color),
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({required this.stage, required this.leads, required this.onLeadTap});

  final String stage;
  final List<LeadItem> leads;
  final ValueChanged<LeadItem> onLeadTap;

  @override
  Widget build(BuildContext context) {
    final color = stageColors[stage] ?? brand;
    return SizedBox(
      width: 270,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border(bottom: BorderSide(color: color, width: 3)),
            ),
            child: Row(
              children: [
                Text(stageEmoji[stage] ?? '•', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stageLabels[stage] ?? stage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${leads.length}',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: leads.isEmpty
                ? Center(
                    child: Text(
                      'No leads',
                      style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: leads.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeIn(
                        delay: i < 10 ? i * 60 : 0,
                        child: _LeadCard(lead: leads[i], accent: color, onTap: () => onLeadTap(leads[i])),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LeadCard extends StatefulWidget {
  const _LeadCard({required this.lead, required this.accent, required this.onTap});

  final LeadItem lead;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends State<_LeadCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final accent = widget.accent;
    final onTap = widget.onTap;
    final initial = lead.name.isEmpty ? '?' : lead.name[0].toUpperCase();
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: _buildCard(lead, accent, onTap, initial),
      ),
    );
  }

  Widget _buildCard(LeadItem lead, Color accent, VoidCallback onTap, String initial) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Text(
                      initial,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lead.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Chip(text: sourceLabels[lead.source] ?? lead.source, color: brand),
                  if ((lead.clientName ?? '').isNotEmpty)
                    _Chip(text: lead.clientName!, color: muted),
                ],
              ),
              if ((lead.phone ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('📱 ${lead.phone}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted)),
              ],
              if (lead.dateLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('🗓️ ${lead.dateLabel}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _LeadSheet extends StatefulWidget {
  const _LeadSheet({required this.lead, required this.stages});

  final LeadItem lead;
  final List<String> stages;

  @override
  State<_LeadSheet> createState() => _LeadSheetState();
}

class _LeadSheetState extends State<_LeadSheet> {
  bool _busy = false;
  late String _stage = widget.lead.stage;

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _move(String stage) async {
    if (stage == _stage) return;
    setState(() => _busy = true);
    try {
      await ApiService.instance.put('/leads/${widget.lead.id}/move', body: {'stage': stage});
      if (mounted) Navigator.of(context).pop('moved');
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this lead?'),
        content: Text('"${widget.lead.name}" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ApiService.instance.delete('/leads/${widget.lead.id}');
      if (mounted) Navigator.of(context).pop('deleted');
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            lead.name,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if ((lead.phone ?? '').isNotEmpty) '📱 ${lead.phone}',
              if ((lead.email ?? '').isNotEmpty) '✉️ ${lead.email}',
            ].join('   '),
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
          ),
          if ((lead.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
              child: Text(
                '📝 ${lead.notes}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ink),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Change stage',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ink),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in widget.stages)
                ChoiceChip(
                  label: Text('${stageEmoji[s] ?? ''} ${stageLabels[s] ?? s}'),
                  selected: _stage == s,
                  selectedColor: (stageColors[s] ?? brand).withValues(alpha: 0.2),
                  onSelected: _busy ? null : (_) {
                    setState(() => _stage = s);
                    _move(s);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, color: bad),
                  label: const Text('Delete lead', style: TextStyle(color: bad)),
                ),
              ),
              if (_busy)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddLeadSheet extends StatefulWidget {
  const _AddLeadSheet({required this.clients});

  final List<ClientOption> clients;

  @override
  State<_AddLeadSheet> createState() => _AddLeadSheetState();
}

class _AddLeadSheetState extends State<_AddLeadSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  String _source = 'WEBSITE';
  late int _clientId = widget.clients.first.id;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('Name is required');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.instance.post('/leads', body: {
        'client_id': _clientId,
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'source': _source,
        'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.of(context).pop('added');
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

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
              '🎯 New lead',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: ink),
            ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: _dec('Name *')),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _dec('Email'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _source,
              decoration: _dec('Source'),
              items: [
                for (final e in sourceLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _source = v ?? _source),
            ),
            if (widget.clients.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _clientId,
                decoration: _dec('Client'),
                items: [
                  for (final c in widget.clients)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _clientId = v ?? _clientId),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: _dec('Notes'),
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
                  : const Text('Save lead'),
            ),
          ],
        ),
      ),
    );
  }
}
