import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/sheet_notice.dart';

/// Add a contact ([contact] null) or view and edit one. Pops with a message
/// when something changed so the list reloads; pops null when nothing did.
class WhatsAppContactSheet extends StatefulWidget {
  const WhatsAppContactSheet({super.key, this.contact});

  final WaContactRecord? contact;

  @override
  State<WhatsAppContactSheet> createState() => _WhatsAppContactSheetState();
}

class _WhatsAppContactSheetState extends State<WhatsAppContactSheet> {
  late final _phone = TextEditingController(text: widget.contact?.phone ?? '');
  late final _name = TextEditingController(text: widget.contact?.name ?? '');
  late final _email = TextEditingController(text: widget.contact?.email ?? '');
  late final _company = TextEditingController(
    text: widget.contact?.company ?? '',
  );
  late final _tags = TextEditingController(text: widget.contact?.tagList ?? '');
  late bool _blocked = widget.contact?.isBlocked ?? false;
  late bool _optedOut = widget.contact?.optedOut ?? false;
  bool _busy = false;
  String? _notice;

  bool get _isNew => widget.contact == null;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _email.dispose();
    _company.dispose();
    _tags.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );

  void _fail(Object e) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _busy = false;
      _notice = errorLine(e);
    });
  }

  String? _validate() {
    if (_isNew) {
      final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 8) {
        return 'Enter the full phone number with the country code.';
      }
    }
    final email = _email.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'That email address does not look right.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final c = widget.contact;
      if (c == null) {
        await WhatsAppService.createContact(
          phone: _phone.text.trim(),
          name: _name.text.trim(),
          email: _email.text.trim(),
          company: _company.text.trim(),
          tags: _tags.text.trim(),
        );
        if (mounted) Navigator.of(context).pop('Contact added.');
      } else {
        await WhatsAppService.updateContact(
          c.id,
          name: _name.text.trim(),
          email: _email.text.trim(),
          company: _company.text.trim(),
          tags: _tags.text.trim(),
          blocked: _blocked,
          optedOut: _optedOut,
        );
        if (mounted) Navigator.of(context).pop('Contact saved.');
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<bool> _confirm(String title, String text, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _delete() async {
    final c = widget.contact!;
    if (!await _confirm(
      'Delete ${c.title}?',
      'The contact is removed from your list. Their past chats stay in the Inbox.',
      'Delete',
    )) {
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await WhatsAppService.deleteContact(c.id);
      if (mounted) Navigator.of(context).pop('${c.title} deleted.');
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _addToBlacklist() async {
    final c = widget.contact!;
    if (!await _confirm(
      'Never message ${c.phone}?',
      'The number goes on the blocked list and is skipped by every send, '
          'including campaigns. You can remove it later.',
      'Block number',
    )) {
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await WhatsAppService.addToBlacklist(c.phone, name: c.name);
      if (mounted) {
        Navigator.of(context).pop('${c.phone} added to blocked numbers.');
      }
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isNew ? 'Add a contact' : c!.title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
              if (c != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    c.phone,
                    if (c.source.isNotEmpty) 'from ${c.source}',
                    if (c.lastInteractionAt != null)
                      'last chat ${fmtDate(c.lastInteractionAt!)}',
                  ].join(' · '),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
                if (c.isHot && c.hotReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bad.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: bad,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.hotReason,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: ink,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              if (_isNew) ...[
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  enabled: !_busy,
                  decoration: _dec('Phone number', hint: '+91 98765 43210'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _company,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('Company'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                enabled: !_busy,
                decoration: _dec('Tags', hint: 'vip, delhi, lead'),
              ),
              if (!_isNew) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Blocked'),
                  subtitle: const Text('Do not send messages to this contact'),
                  value: _blocked,
                  onChanged: _busy ? null : (v) => setState(() => _blocked = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Opted out'),
                  subtitle: const Text('They asked to stop receiving messages'),
                  value: _optedOut,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _optedOut = v),
                ),
              ],
              const SizedBox(height: 12),
              SheetNotice(_notice),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isNew ? 'Add contact' : 'Save changes'),
              ),
              if (!_isNew) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addToBlacklist,
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Add number to blocked list'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: bad),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete contact'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
