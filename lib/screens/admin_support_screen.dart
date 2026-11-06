import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/account_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';

const _statuses = ['open', 'in_progress', 'resolved', 'closed'];

String _statusLabel(String s) => s.replaceAll('_', ' ');

/// Tickets from every company. Reply and set the status.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  List<SupportTicket> _tickets = [];
  bool _loading = true;
  String? _error;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await AdminService.tickets(status: _filter);
      if (!mounted) return;
      setState(() {
        _tickets = t;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(String? f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _loading = true;
    });
    _load();
  }

  Future<void> _open(SupportTicket t) async {
    final updated = await showAdminSheet<SupportTicket>(
      context,
      (_) => _TicketSheet(ticket: t),
    );
    if (updated == null) return;
    if (mounted) {
      NoticeScope.show(context, 'Reply sent');
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in <String?>[null, ..._statuses])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s == null ? 'All' : _statusLabel(s)),
                        selected: _filter == s,
                        showCheckmark: false,
                        onSelected: (_) => _setFilter(s),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AdminMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load tickets',
                text: _error!,
                onRetry: _load,
              )
            else if (_tickets.isEmpty)
              const AdminMessage(
                icon: Icons.inbox_outlined,
                title: 'No tickets',
              )
            else
              for (var i = 0; i < _tickets.length; i++)
                FadeIn(
                  delay: i < 8 ? i * 40 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _open(_tickets[i]),
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
                                      _tickets[i].subject,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AdminBadge(
                                    _statusLabel(_tickets[i].status),
                                    adminStatusColor(_tickets[i].status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  if ((_tickets[i].tenantName ?? '').isNotEmpty)
                                    _tickets[i].tenantName!,
                                  if ((_tickets[i].userName ?? '').isNotEmpty)
                                    _tickets[i].userName!,
                                  _tickets[i].ticketId,
                                  if (_tickets[i].createdAt != null)
                                    fmtDate(_tickets[i].createdAt!),
                                ].join('  ·  '),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
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

class _TicketSheet extends StatefulWidget {
  const _TicketSheet({required this.ticket});

  final SupportTicket ticket;

  @override
  State<_TicketSheet> createState() => _TicketSheetState();
}

class _TicketSheetState extends State<_TicketSheet> {
  late final _reply = TextEditingController(text: widget.ticket.adminReply ?? '');
  late String _status =
      widget.ticket.status == 'open' ? 'in_progress' : widget.ticket.status;
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) {
      NoticeScope.show(context, 'Write a reply first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final t = await AdminService.replyToTicket(
        widget.ticket.id,
        reply: _reply.text.trim(),
        status: _status,
      );
      if (mounted) Navigator.of(context).pop(t);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        NoticeScope.show(context, friendlyException(e).message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSheetHeader(t.subject),
              Text(
                [
                  if ((t.tenantName ?? '').isNotEmpty) t.tenantName!,
                  if ((t.userName ?? '').isNotEmpty) t.userName!,
                  if ((t.userEmail ?? '').isNotEmpty) t.userEmail!,
                ].join('  ·  '),
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 12),
              Text(
                t.description,
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, height: 1.45, color: ink),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _reply,
                minLines: 4,
                maxLines: 8,
                maxLength: 5000,
                decoration: adminInput('Your reply'),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: adminInput('Set status'),
                items: [
                  for (final s in _statuses)
                    DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(t.hasReply ? 'Update reply' : 'Send reply'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
