import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/agents_models.dart';
import '../services/access_problem.dart';
import '../services/agents_service.dart';
import '../theme/brand.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_ui.dart';

/// Gives a chat to a person, or takes it back. Pops with an [AssignResult]
/// when something changed, and with nothing when it was just closed.
class AssignAgentSheet extends StatefulWidget {
  const AssignAgentSheet({
    super.key,
    required this.conversationId,
    this.currentAgent = '',
  });

  final String conversationId;

  /// Who has the chat now, by name; empty when nobody does.
  final String currentAgent;

  @override
  State<AssignAgentSheet> createState() => _AssignAgentSheetState();
}

class _AssignAgentSheetState extends State<AssignAgentSheet> {
  List<WaAssignable> _people = [];
  String? _picked;
  bool _loading = true;
  bool _busy = false;
  String? _notice;

  bool get _assigned => widget.currentAgent.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final people = await AgentsService.assignable();
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notice = errorLine(e);
        _loading = false;
      });
    }
  }

  Future<void> _assign() async {
    final id = _picked;
    if (id == null || _busy) return;
    final person = _people.firstWhere((p) => p.id == id);
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final message = await AgentsService.assign(widget.conversationId, id);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(AssignResult(agentName: person.name, message: message));
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _busy = false;
        _notice = errorLine(e);
      });
    }
  }

  Future<void> _unassign() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final message = await AgentsService.unassign(widget.conversationId);
      if (!mounted) return;
      Navigator.of(context).pop(AssignResult(agentName: '', message: message));
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _busy = false;
        _notice = errorLine(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Give this chat to',
      subtitle: _assigned
          ? 'Now with ${widget.currentAgent}.'
          : 'Nobody has this chat yet.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No one is available to take chats.',
                style: GoogleFonts.plusJakartaSans(color: muted),
              ),
            )
          else
            RadioGroup<String>(
              groupValue: _picked,
              onChanged: (v) {
                if (!_busy) setState(() => _picked = v);
              },
              child: Column(
                children: [
                  for (final p in _people)
                    RadioListTile<String>(
                      value: p.id,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p.isMe ? '${p.name} (you)' : p.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'A chat that has someone assigned is not answered by the '
            'chatbot: that person replies.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _picked == null || _busy ? null : _assign,
            child: _busy
                ? Semantics(
                    label: 'Saving',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Text('Assign'),
          ),
          if (_assigned)
            TextButton(
              onPressed: _busy ? null : _unassign,
              child: const Text('Take it back (unassign)'),
            ),
        ],
      ),
    );
  }
}
