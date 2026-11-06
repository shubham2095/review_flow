import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/account_models.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../services/local_draft.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/pressable.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';

const _supportEmail = 'support@eydia.in';
const _draftKey = 'support_ticket';

const _categories = {
  'billing': ('Billing', Icons.receipt_long_rounded),
  'technical': ('Technical', Icons.build_rounded),
  'account': ('Account', Icons.person_rounded),
  'other': ('Other', Icons.help_outline_rounded),
};

Color _statusColor(String status) {
  switch (status) {
    case 'resolved':
    case 'closed':
      return good;
    case 'in_progress':
      return brand;
    default:
      return warn;
  }
}

String _statusLabel(String status) => status.replaceAll('_', ' ');

bool _isDone(String status) => status == 'resolved' || status == 'closed';

/// Help and support: your tickets and a form to raise a new one.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<SupportTicket> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await AccountService.tickets();
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newTicket() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _NewTicketSheet(),
    );
    if (created == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket sent. We will reply here.')),
        );
      }
      await _load();
    }
  }

  void _open(SupportTicket t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _TicketSheet(ticket: t),
    );
  }

  Future<void> _emailSupport() async {
    try {
      final ok = await launchUrl(
        Uri(scheme: 'mailto', path: _supportEmail),
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    } catch (_) {}
    // No mail app: copy the address so it can be pasted anywhere.
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email address copied.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tickets waiting for an answer first, finished ones after.
    final open = _tickets.where((t) => !_isDone(t.status)).toList();
    final done = _tickets.where((t) => _isDone(t.status)).toList();
    var delay = 0;
    Widget card(SupportTicket t) => FadeIn(
          delay: (delay++ * 50).clamp(0, 400),
          child: _TicketCard(ticket: t, onTap: () => _open(t)),
        );

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(title: const Text('Help & support')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTicket,
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New ticket'),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading
            ? const SkeletonList(count: 4, itemHeight: 88)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null && _tickets.isEmpty)
                    StateView.error(
                      title: 'Could not load tickets',
                      text: _error!,
                      onRetry: _load,
                    )
                  else if (_tickets.isEmpty)
                    StateView(
                      icon: Icons.support_agent_rounded,
                      title: 'No tickets yet',
                      text:
                          'Having trouble? Raise a ticket and our team will reply here.',
                      actionLabel: 'Raise a ticket',
                      onAction: _newTicket,
                    )
                  else ...[
                    if (open.isNotEmpty) ...[
                      _GroupTitle('Open', open.length),
                      for (final t in open) card(t),
                    ],
                    if (done.isNotEmpty) ...[
                      _GroupTitle('Resolved', done.length),
                      for (final t in done) card(t),
                    ],
                  ],
                  const SizedBox(height: 8),
                  _EmailCard(onTap: _emailSupport),
                ],
              ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text, this.count);

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        '$text  ·  $count',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: muted,
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final color = _statusColor(t.status);
    final cat = _categories[t.category]?.$2 ?? Icons.confirmation_number_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        onTap: onTap,
        scale: 0.985,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(cat, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(t.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${t.ticketId}${t.createdAt == null ? '' : '  ·  ${fmtDate(t.createdAt!)}'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: muted,
                      ),
                    ),
                    if (t.hasReply) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.mark_chat_read_rounded,
                            size: 14,
                            color: good,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Reply from support',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: good,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// A way to reach support that does not depend on the ticket form working.
class _EmailCard extends StatelessWidget {
  const _EmailCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.mail_rounded, size: 20, color: brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prefer email?',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Text(
                    _supportEmail,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: brand),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  const _NewTicketSheet();

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _category = 'technical';
  bool _sending = false;
  bool _sent = false;
  Timer? _saveTimer;

  // Shown inside the sheet: a snack bar would sit behind it.
  String? _notice;
  bool _noticeError = true;
  String? _subjectError;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    for (final c in [_subject, _description]) {
      c.addListener(_onEdit);
    }
  }

  Future<void> _restoreDraft() async {
    final d = await LocalDraft.read(_draftKey);
    if (d == null || !mounted) return;
    final subject = (d['subject'] as String?) ?? '';
    final description = (d['description'] as String?) ?? '';
    if (subject.trim().isEmpty && description.trim().isEmpty) return;
    _subject.text = subject;
    _description.text = description;
    final cat = d['category'] as String?;
    setState(() {
      if (cat != null && _categories.containsKey(cat)) _category = cat;
      _notice = 'Your unsent ticket was restored.';
      _noticeError = false;
    });
  }

  void _onEdit() {
    if (_subjectError != null || _descriptionError != null) {
      setState(() {
        _subjectError = null;
        _descriptionError = null;
      });
    }
    _scheduleSave();
  }

  void _scheduleSave() {
    if (_sent) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  void _saveNow() {
    if (_sent) return;
    if (_subject.text.trim().isEmpty && _description.text.trim().isEmpty) {
      LocalDraft.clear(_draftKey);
    } else {
      LocalDraft.save(_draftKey, {
        'subject': _subject.text,
        'description': _description.text,
        'category': _category,
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final description = _description.text.trim();
    String? subjectError;
    String? descriptionError;
    if (subject.isEmpty) subjectError = 'Add a short subject.';
    if (description.length < 10) {
      descriptionError = 'Describe the problem in a few words (at least 10 characters).';
    }
    if (subjectError != null || descriptionError != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _subjectError = subjectError;
        _descriptionError = descriptionError;
        _notice = null;
      });
      return;
    }
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      await AccountService.createTicket(
        subject: subject,
        description: description,
        category: _category,
      );
      _sent = true;
      _saveTimer?.cancel();
      await LocalDraft.clear(_draftKey);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _sending = false;
          _notice = friendlyException(e).message;
          _noticeError = true;
        });
      }
    }
  }

  InputDecoration _dec(String label, {String? hint, String? errorText}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New support ticket',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tell us what happened. The more detail, the faster we can help.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in _categories.entries)
                  ChoiceChip(
                    avatar: Icon(
                      e.value.$2,
                      size: 16,
                      color: _category == e.key ? brand : muted,
                    ),
                    label: Text(e.value.$1),
                    selected: _category == e.key,
                    showCheckmark: false,
                    onSelected: _sending
                        ? null
                        : (_) {
                            setState(() => _category = e.key);
                            _scheduleSave();
                          },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subject,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Subject', errorText: _subjectError),
              maxLength: 255,
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              maxLength: 5000,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(
                'What is the problem?',
                hint: 'What were you doing, and what did you see?',
                errorText: _descriptionError,
              ),
            ),
            const SizedBox(height: 8),
            SheetNotice(_notice, error: _noticeError),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketSheet extends StatelessWidget {
  const _TicketSheet({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      t.subject,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(t.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '${t.ticketId}${t.createdAt == null ? '' : '  ·  ${fmtDate(t.createdAt!)}'}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                    ),
                  ),
                  // Support asks for the ticket number: one tap to copy it.
                  IconButton(
                    tooltip: 'Copy ticket number',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 16, color: muted),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: t.ticketId));
                      if (context.mounted) {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ticket number copied.')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Bubble(label: 'You', text: t.description, color: brand),
              if (t.hasReply) ...[
                const SizedBox(height: 12),
                _Bubble(
                  label: t.repliedAt == null
                      ? 'Support'
                      : 'Support, ${fmtDate(t.repliedAt!)}',
                  text: t.adminReply!,
                  color: good,
                ),
              ] else if (!_isDone(t.status)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 15, color: muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Waiting for a reply from our team.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.label, required this.text, required this.color});

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.45,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}
