import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/wa_ui.dart';

/// Connects a WhatsApp number by hand with the ids and token from Meta.
/// Pops with a success message when the number was connected.
class WhatsAppConnectSheet extends StatefulWidget {
  const WhatsAppConnectSheet({super.key});

  @override
  State<WhatsAppConnectSheet> createState() => _WhatsAppConnectSheetState();
}

class _WhatsAppConnectSheetState extends State<WhatsAppConnectSheet> {
  final _waba = TextEditingController();
  final _phoneId = TextEditingController();
  final _display = TextEditingController();
  final _token = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _waba.dispose();
    _phoneId.dispose();
    _display.dispose();
    _token.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final waba = _waba.text.trim();
    final phoneId = _phoneId.text.trim();
    final display = _display.text.trim();
    final token = _token.text.trim();
    String? problem;
    if (waba.isEmpty || phoneId.isEmpty || display.isEmpty || token.isEmpty) {
      problem = 'Fill in the account ID, phone number ID, number and token.';
    } else if (token.length < 20) {
      problem = 'That access token looks too short.';
    }
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
      final number = await WhatsAppService.connectManual(
        wabaId: waba,
        phoneNumberId: phoneId,
        displayNumber: display,
        accessToken: token,
        name: _name.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop('${number.displayNumber} connected.');
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
      title: 'Connect a WhatsApp number',
      subtitle:
          'Copy these from Meta: open WhatsApp Manager, then API setup. The '
          'token is stored on the server and never shown again.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _waba,
            keyboardType: TextInputType.number,
            enabled: !_busy,
            decoration: waInputDecoration(
              'WhatsApp Business Account ID',
              helper: 'API setup, under "WhatsApp Business Account ID".',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneId,
            keyboardType: TextInputType.number,
            enabled: !_busy,
            decoration: waInputDecoration(
              'Phone number ID',
              helper:
                  'API setup, under "Phone number ID". This is not the phone '
                  'number itself.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _display,
            keyboardType: TextInputType.phone,
            enabled: !_busy,
            decoration: waInputDecoration(
              'Phone number',
              hint: '+91 98765 43210',
              helper: 'The number customers see, with the country code.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            enabled: !_busy,
            decoration: waInputDecoration(
              'Access token',
              helper:
                  'A permanent token from a Meta system user. A temporary one '
                  'stops working after about a day.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            enabled: !_busy,
            decoration: waInputDecoration(
              'Label (optional)',
              helper: 'A name only you see, such as "Support" or "Sales".',
            ),
          ),
          const SizedBox(height: 16),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy ? null : _connect,
            child: _busy
                ? Semantics(
                    label: 'Connecting',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Text('Connect number'),
          ),
        ],
      ),
    );
  }
}
