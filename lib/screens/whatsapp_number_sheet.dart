import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_ui.dart';

/// Actions for one connected number. Pops with a message when something
/// changed (so the list reloads and shows it); pops null when nothing did.
class WhatsAppNumberSheet extends StatefulWidget {
  const WhatsAppNumberSheet({super.key, required this.number});

  final WaNumber number;

  @override
  State<WhatsAppNumberSheet> createState() => _WhatsAppNumberSheetState();
}

class _WhatsAppNumberSheetState extends State<WhatsAppNumberSheet> {
  late WaNumber _n = widget.number;
  bool _busy = false;
  String? _notice;
  bool _noticeIsError = true;
  String? _changed;

  void _show(String text, {bool error = true}) {
    if (error) HapticFeedback.lightImpact();
    setState(() {
      _notice = text;
      _noticeIsError = error;
    });
  }

  /// Runs one server action with the busy lock and shows its outcome here, in
  /// the sheet (a snack bar would sit behind it).
  Future<void> _run(
    Future<String> Function() action, {
    bool changes = true,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final message = await action();
      if (!mounted) return;
      if (changes) _changed = message;
      _show(message, error: false);
    } catch (e) {
      if (mounted) _show(errorLine(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(
    String title,
    String label, {
    String? help,
    bool secret = false,
    int? digits,
    TextInputType? keyboard,
    String confirm = 'Continue',
  }) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (help != null) ...[
              Text(help, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: c,
              autofocus: true,
              obscureText: secret,
              enableSuggestions: !secret,
              autocorrect: !secret,
              keyboardType: keyboard,
              maxLength: digits,
              inputFormatters: digits == null
                  ? null
                  : [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: label),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTest() async {
    final to = await _ask(
      'Send a test message',
      'Phone number to send to',
      help:
          'Sends the approved "hello_world" template. Use a number that can '
          'receive WhatsApp, with the country code.',
      keyboard: TextInputType.phone,
      confirm: 'Send',
    );
    if (to == null || to.replaceAll(RegExp(r'\D'), '').length < 8) {
      if (to != null) _show('Enter a full phone number with the country code.');
      return;
    }
    await _run(() async {
      await WhatsAppService.sendTest(_n.id, to);
      return 'Test message sent to $to.';
    }, changes: false);
  }

  Future<void> _register() async {
    final pin = await _ask(
      'Enable sending',
      '6-digit PIN',
      help:
          'Registers this number on the WhatsApp Cloud API. If it already has '
          'a two-step PIN, enter that; otherwise choose a new 6-digit one.',
      digits: 6,
      keyboard: TextInputType.number,
      secret: true,
      confirm: 'Enable',
    );
    if (pin == null) return;
    if (pin.length != 6) {
      _show('The PIN must be exactly 6 digits.');
      return;
    }
    await _run(() async {
      final fresh = await WhatsAppService.register(_n.id, pin);
      if (mounted) setState(() => _n = fresh);
      return 'Sending enabled for ${_n.displayNumber}.';
    });
  }

  Future<void> _token() async {
    final token = await _ask(
      'Update access token',
      'New access token',
      help: 'Use this when Meta says the token expired or has no permission.',
      secret: true,
      confirm: 'Update',
    );
    if (token == null) return;
    if (token.length < 10) {
      _show('That access token looks too short.');
      return;
    }
    await _run(() => WhatsAppService.updateToken(_n.id, token));
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disconnect ${_n.displayNumber}?'),
        content: const Text(
          'You will stop receiving and sending messages on this number from '
          'Eydia. You can connect it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final message = await WhatsAppService.disconnect(_n.id);
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _show(errorLine(e));
      }
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _show('$label copied.', error: false);
  }

  @override
  Widget build(BuildContext context) {
    final n = _n;
    final quality = qualityMeaning(n.quality);
    final status = numberStatusMeaning(n.status);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) Navigator.of(context).pop(_changed);
      },
      child: AppSheet(
        title: n.displayNumber,
        subtitle: n.verifiedName.isEmpty ? null : n.verifiedName,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoChip(
                  n.isRegistered ? 'Sending enabled' : 'Sending not enabled',
                  icon: n.isRegistered
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: n.isRegistered ? good : warn,
                ),
                if (n.status.isNotEmpty) InfoChip(n.status),
                if (n.quality.isNotEmpty) InfoChip('Quality ${n.quality}'),
                if (n.isDefault) const InfoChip('Default', color: brand),
              ],
            ),
            if (!n.isRegistered)
              const _Explain(
                'Sending is not enabled yet. Use "Enable sending" below, or '
                'messages from this number will not go out.',
                color: warn,
              ),
            if (quality != null) _Explain(quality),
            if (status != null) _Explain(status),
            const SizedBox(height: 10),
            SheetNotice(_notice, error: _noticeIsError),
            const SectionTitle('Check and refresh', padding: _groupPad),
            _Action(
              Icons.send_rounded,
              'Send a test message',
              'Check that this number can send',
              _busy ? null : _sendTest,
            ),
            _Action(
              Icons.sync_rounded,
              'Refresh from Meta',
              'Update name, status and quality',
              _busy
                  ? null
                  : () => _run(() async {
                      final fresh = await WhatsAppService.sync(n.id);
                      if (mounted) setState(() => _n = fresh);
                      return '${fresh.displayNumber} is up to date.';
                    }),
            ),
            const SectionTitle('Sending setup', padding: _groupPad),
            if (!n.isRegistered)
              _Action(
                Icons.verified_user_rounded,
                'Enable sending',
                'Register this number with a 6-digit PIN',
                _busy ? null : _register,
              ),
            _Action(
              Icons.build_circle_outlined,
              'Fix "no permission to send"',
              'Re-subscribe the app to the business account',
              _busy
                  ? null
                  : () => _run(() => WhatsAppService.subscribeApp(n.id)),
            ),
            _Action(
              Icons.key_rounded,
              'Update access token',
              'Paste a new token from Meta',
              _busy ? null : _token,
            ),
            const SectionTitle('Ids to copy', padding: _groupPad),
            _CopyRow('Phone number', n.displayNumber, _copy),
            if (n.phoneNumberId.isNotEmpty)
              _CopyRow('Phone number ID', n.phoneNumberId, _copy),
            const SectionTitle('Danger zone', padding: _groupPad),
            _Action(
              Icons.link_off_rounded,
              'Disconnect number',
              'Stop using it in Eydia',
              _busy ? null : _disconnect,
              danger: true,
            ),
            if (_busy)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  label: 'Working',
                  child: const LinearProgressIndicator(minHeight: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _groupPad = EdgeInsets.fromLTRB(0, 18, 0, 4);

/// What the quality rating from Meta means, in plain words. Null when the
/// rating is empty or unknown.
String? qualityMeaning(String quality) {
  switch (quality.trim().toLowerCase()) {
    case 'green':
    case 'high':
      return 'Quality Green: customers are happy with your messages. You can '
          'send at your normal limit.';
    case 'yellow':
    case 'medium':
      return 'Quality Yellow: some customers are blocking or reporting you. '
          'Send fewer messages and only to people who asked for them.';
    case 'red':
    case 'low':
      return 'Quality Red: many customers are blocking or reporting you. Meta '
          'may limit this number. Pause promotions and send only wanted '
          'messages.';
    default:
      return null;
  }
}

/// What the number status from Meta means. Null when empty or unknown.
String? numberStatusMeaning(String status) {
  switch (status.trim().toUpperCase()) {
    case 'CONNECTED':
      return 'Status Connected: the number is working with WhatsApp.';
    case 'PENDING':
      return 'Status Pending: Meta is still checking this number. Try '
          '"Refresh from Meta" in a little while.';
    case 'FLAGGED':
      return 'Status Flagged: Meta has flagged this number for low quality. '
          'It can be restricted if quality does not improve.';
    case 'RESTRICTED':
      return 'Status Restricted: Meta has limited what this number can send. '
          'Check WhatsApp Manager for the reason.';
    case 'DISCONNECTED':
      return 'Status Disconnected: the number is not connected to WhatsApp. '
          'Check it in WhatsApp Manager.';
    case 'BANNED':
      return 'Status Banned: Meta has banned this number. Contact Meta '
          'support.';
    default:
      return null;
  }
}

/// One plain sentence under the chips.
class _Explain extends StatelessWidget {
  const _Explain(this.text, {this.color = inkSoft});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          color: color,
          height: 1.4,
        ),
      ),
    );
  }
}

/// A label and value with a button that copies the value.
class _CopyRow extends StatelessWidget {
  const _CopyRow(this.label, this.value, this.onCopy);

  final String label;
  final String value;
  final Future<void> Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: muted,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy $label',
          icon: const Icon(Icons.copy_rounded, size: 20),
          color: brand,
          onPressed: () => onCopy(label, value),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? bad : ink;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      onTap: onTap,
      leading: ExcludeSemantics(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (danger ? bad : brand).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: danger ? bad : brand),
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
      ),
    );
  }
}
