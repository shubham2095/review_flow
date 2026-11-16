import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_ui.dart';

/// Splits typed tag text ("vip, delhi; lead") into clean tags. Duplicates
/// (ignoring capitals) are dropped and the order is kept.
List<String> parseTags(String raw, {List<String> existing = const []}) {
  final seen = existing.map((t) => t.toLowerCase()).toSet();
  final added = <String>[];
  for (final piece in raw.split(RegExp(r'[,;|]'))) {
    final tag = piece.trim();
    if (tag.isEmpty) continue;
    if (seen.add(tag.toLowerCase())) added.add(tag);
  }
  return [...existing, ...added];
}

/// Add a contact ([contact] null) or look at one and edit it. An existing
/// contact opens in a read-only view (details, call, copy); "Edit contact"
/// switches to the form. Pops with a message when something changed so the
/// list reloads; pops null when nothing did.
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
  final _tagInput = TextEditingController();
  late List<String> _tags = parseTags(widget.contact?.tagList ?? '');
  late bool _blocked = widget.contact?.isBlocked ?? false;
  late bool _optedOut = widget.contact?.optedOut ?? false;

  /// A new contact starts in the form; an existing one starts in the view.
  late bool _editing = widget.contact == null;
  bool _busy = false;
  String? _notice;

  bool get _isNew => widget.contact == null;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _email.dispose();
    _company.dispose();
    _tagInput.dispose();
    super.dispose();
  }

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

  void _addTagsFromInput() {
    if (_tagInput.text.trim().isEmpty) return;
    setState(() {
      _tags = parseTags(_tagInput.text, existing: _tags);
      _tagInput.clear();
    });
  }

  Future<void> _save() async {
    // A tag typed but not yet added still counts.
    _addTagsFromInput();
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
      final tagText = _tags.join(', ');
      if (c == null) {
        await WhatsAppService.createContact(
          phone: _phone.text.trim(),
          name: _name.text.trim(),
          email: _email.text.trim(),
          company: _company.text.trim(),
          tags: tagText,
        );
        if (mounted) Navigator.of(context).pop('Contact added.');
      } else {
        await WhatsAppService.updateContact(
          c.id,
          name: _name.text.trim(),
          email: _email.text.trim(),
          company: _company.text.trim(),
          tags: tagText,
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

  Future<void> _call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('tel:+$digits'));
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) showToast(context, 'Could not start a call.');
  }

  Future<void> _copy(String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) showToast(context, 'Number copied.');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return AppSheet(
      title: _isNew
          ? 'Add a contact'
          : (_editing ? 'Edit contact' : c!.title),
      child: _editing ? _form() : _view(c!),
    );
  }

  // ---- Read-only view --------------------------------------------------

  Widget _detailRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _view(WaContactRecord c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ContactAvatar(name: c.title, radius: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.phone,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: ink,
                    ),
                  ),
                  if (c.isHot || c.isBlocked || c.optedOut) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (c.isHot)
                          const InfoChip(
                            'Hot lead',
                            icon: Icons.local_fire_department_rounded,
                            color: bad,
                          ),
                        if (c.isBlocked)
                          const InfoChip(
                            'Blocked',
                            icon: Icons.block_rounded,
                            color: muted,
                          ),
                        if (c.optedOut)
                          const InfoChip(
                            'Opted out',
                            icon: Icons.unsubscribe_rounded,
                            color: warn,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (c.isHot && c.hotReason.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bad.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              c.hotReason,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: ink,
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(c.phone),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy number'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _call(c.phone),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _detailRow('Email', c.email),
        _detailRow('Company', c.company),
        _detailRow('Source', c.source),
        _detailRow(
          'Last chat',
          c.lastInteractionAt == null ? '' : fmtDate(c.lastInteractionAt!),
        ),
        _detailRow('Assigned to', c.agentName),
        const SizedBox(height: 4),
        Text(
          'Tags',
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
        ),
        const SizedBox(height: 6),
        if (c.tags.isEmpty)
          Text(
            'No tags yet. Tap Edit contact to add some.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [for (final t in c.tags) InfoChip(t, color: brand)],
          ),
        const SizedBox(height: 18),
        SheetNotice(_notice),
        FilledButton.icon(
          onPressed: _busy ? null : () => setState(() => _editing = true),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Edit contact'),
        ),
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
    );
  }

  // ---- Form ------------------------------------------------------------

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isNew) ...[
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            enabled: !_busy,
            decoration: waInputDecoration(
              'Phone number',
              hint: '+91 98765 43210',
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _name,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: waInputDecoration('Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: waInputDecoration('Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _company,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: waInputDecoration('Company'),
        ),
        const SizedBox(height: 16),
        Text(
          'Tags',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: ink,
          ),
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final t in _tags)
                InputChip(
                  label: Text(t),
                  onDeleted: _busy
                      ? null
                      : () => setState(() => _tags = [..._tags]..remove(t)),
                  deleteButtonTooltipMessage: 'Remove tag $t',
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _tagInput,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addTagsFromInput(),
          decoration: waInputDecoration(
            'Add a tag',
            hint: 'vip, delhi, lead',
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: 'Add tag',
              icon: const Icon(Icons.add_circle_rounded, color: brand),
              onPressed: _busy ? null : _addTagsFromInput,
            ),
          ),
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
            onChanged: _busy ? null : (v) => setState(() => _optedOut = v),
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
        if (!_isNew)
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    // Back to the read-only view, dropping unsaved edits.
                    final c = widget.contact!;
                    _name.text = c.name;
                    _email.text = c.email;
                    _company.text = c.company;
                    _tags = parseTags(c.tagList);
                    _tagInput.clear();
                    _blocked = c.isBlocked;
                    _optedOut = c.optedOut;
                    _notice = null;
                    _editing = false;
                  }),
            child: const Text('Cancel'),
          ),
      ],
    );
  }
}
