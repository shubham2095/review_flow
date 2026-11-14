import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/access_problem.dart';
import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/sheet_notice.dart';

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
                'Connect a WhatsApp number',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Copy these from Meta WhatsApp Manager (API setup). The token '
                'is stored on the server and never shown again.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _waba,
                keyboardType: TextInputType.number,
                enabled: !_busy,
                decoration: _dec('WhatsApp Business Account ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneId,
                keyboardType: TextInputType.number,
                enabled: !_busy,
                decoration: _dec('Phone number ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _display,
                keyboardType: TextInputType.phone,
                enabled: !_busy,
                decoration: _dec('Phone number', hint: '+91 98765 43210'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _token,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                enabled: !_busy,
                decoration: _dec('Access token'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                enabled: !_busy,
                decoration: _dec('Label (optional)'),
              ),
              const SizedBox(height: 16),
              SheetNotice(_notice),
              FilledButton(
                onPressed: _busy ? null : _connect,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Connect number'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
