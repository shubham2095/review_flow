import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/whatsapp_models.dart';
import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/sheet_notice.dart';

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

  @override
  Widget build(BuildContext context) {
    final n = _n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) Navigator.of(context).pop(_changed);
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                n.displayNumber,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: ink,
                ),
              ),
              if (n.verifiedName.isNotEmpty)
                Text(
                  n.verifiedName,
                  style: GoogleFonts.plusJakartaSans(color: muted),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Chip(
                    n.isRegistered ? 'Sending enabled' : 'Sending not enabled',
                    n.isRegistered ? good : warn,
                  ),
                  if (n.status.isNotEmpty) _Chip(n.status, muted),
                  if (n.quality.isNotEmpty)
                    _Chip('Quality ${n.quality}', muted),
                  if (n.isDefault) const _Chip('Default', brand),
                ],
              ),
              const SizedBox(height: 14),
              SheetNotice(_notice, error: _noticeIsError),
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
              _Action(
                Icons.link_off_rounded,
                'Disconnect number',
                'Stop using it in Eydia',
                _busy ? null : _disconnect,
                danger: true,
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
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
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (danger ? bad : brand).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: danger ? bad : brand),
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
