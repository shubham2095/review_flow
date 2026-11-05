import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/account_models.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';

const _categories = {
  'billing': 'Billing',
  'technical': 'Technical',
  'account': 'Account',
  'other': 'Other',
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
          const SnackBar(content: Text('Ticket sent. We will get back to you.')),
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

  @override
  Widget build(BuildContext context) {
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
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 44, color: muted),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          FilledButton(onPressed: _load, child: const Text('Try again')),
                        ],
                      ),
                    )
                  else if (_tickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 12),
                      child: Column(
                        children: [
                          const Icon(Icons.support_agent_rounded, size: 48, color: muted),
                          const SizedBox(height: 12),
                          Text(
                            'No tickets yet',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Having trouble? Raise a ticket and our team will reply here.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final t in _tickets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _open(t),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: cardDecoration(),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(t.status).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _statusLabel(t.status).toUpperCase(),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: _statusColor(t.status),
                                          ),
                                        ),
                                      ),
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
                          ),
                        ),
                      ),
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

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final description = _description.text.trim();
    if (subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a subject and describe the problem.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await AccountService.createTicket(
        subject: subject,
        description: description,
        category: _category,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyException(e).message)),
        );
      }
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
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
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _categories.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _category == e.key,
                    showCheckmark: false,
                    onSelected: _sending ? null : (_) => setState(() => _category = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _subject, decoration: _dec('Subject'), maxLength: 255),
            const SizedBox(height: 4),
            TextField(
              controller: _description,
              minLines: 4,
              maxLines: 8,
              maxLength: 5000,
              decoration: _dec('What is the problem?'),
            ),
            const SizedBox(height: 8),
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
              Text(
                ticket.subject,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ticket.ticketId}  ·  ${_statusLabel(ticket.status)}',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 14),
              Text(
                ticket.description,
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, height: 1.45, color: ink),
              ),
              if (ticket.hasReply) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: good.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.repliedAt == null
                            ? 'Reply from support'
                            : 'Reply from support, ${fmtDate(ticket.repliedAt!)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: good,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ticket.adminReply!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          height: 1.45,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
