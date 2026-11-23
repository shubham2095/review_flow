import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/otp_login.dart';
import '../services/platform_rules.dart';
import '../services/session.dart';
import '../services/web_handoff.dart';
import '../theme/brand.dart';
import '../widgets/sheet_notice.dart';

typedef DeleteAccountCall =
    Future<void> Function({String? password, String? idToken, String? code});

/// "Delete your account": the person types DELETE, then proves it is them with
/// their password, a Google sign-in, or (for an account made with a mobile
/// number, which has no password) a 6-digit code sent on WhatsApp to their own
/// number. Closes with `true` once the account is gone.
///
/// [phone] and [codeFirst] default to the signed-in account; [requestCode] and
/// [delete] are the server calls, replaceable in tests.
class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({
    super.key,
    this.phone,
    this.codeFirst,
    this.requestCode,
    this.delete,
  });

  final String? phone;
  final bool? codeFirst;
  final OtpRequest? requestCode;
  final DeleteAccountCall? delete;

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _busy = false;
  bool _hide = true;

  /// The person's own number with its country code, or null when the account
  /// has none (then a code cannot be sent).
  late final String? _full = normalizeOtpPhone(
    widget.phone ?? Session.current?.phone ?? '',
  );
  late bool _useCode =
      _full != null &&
      (widget.codeFirst ??
          deleteWithCodeFirst(
            hasPhone: true,
            standInEmail: Session.current?.hasStandInEmail ?? false,
          ));
  bool _sent = false;
  int _cooldown = 0;
  Timer? _timer;

  // Shown inside the sheet: a snack bar would sit behind it.
  String? _notice;
  bool _noticeIsError = true;
  String? _passwordError;

  /// Deleting is permanent: the person has to type the word, not just tap.
  bool get _confirmed => _confirm.text.trim().toUpperCase() == 'DELETE';

  DeleteAccountCall get _delete => widget.delete ?? AuthService.deleteAccount;
  OtpRequest get _requestCode => widget.requestCode ?? AuthService.requestOtp;

  @override
  void dispose() {
    _timer?.cancel();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = kOtpResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on SignInCancelled {
      // The person closed the Google chooser: nothing happened, nothing to say.
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      final error = friendlyException(e);
      // A wrong code is typed again from scratch.
      if (_useCode && error.statusCode == 422) _code.clear();
      setState(() {
        _busy = false;
        _noticeIsError = true;
        _notice = _useCode ? otpDeleteErrorMessage(error) : error.message;
      });
    }
  }

  Future<void> _withPassword() async {
    if (_password.text.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _passwordError = 'Enter your password to confirm.');
      return;
    }
    await _run(() => _delete(password: _password.text));
  }

  Future<void> _withGoogle() async {
    await _run(() async {
      final idToken = await AuthService.googleIdToken();
      await _delete(idToken: idToken);
    });
  }

  Future<void> _withCode() async {
    if (!otpCodeComplete(_code.text)) return;
    await _run(() => _delete(code: _code.text));
  }

  Future<void> _sendCode() async {
    final to = _full;
    if (_busy || to == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await _requestCode(to, register: false);
      if (!mounted) return;
      final first = !_sent;
      setState(() {
        _busy = false;
        _sent = true;
        _noticeIsError = false;
        _notice = result.devCode != null
            ? 'Test code: ${result.devCode}'
            : (first ? null : 'A new code is on its way.');
      });
      _code.clear();
      _startCooldown();
      if (first) _codeFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _noticeIsError = true;
        _notice = otpErrorMessage(friendlyException(e));
      });
    }
  }

  void _switchTo({required bool code}) {
    setState(() {
      _useCode = code;
      _notice = null;
      _passwordError = null;
    });
  }

  InputDecoration _decoration(
    String label, {
    String? errorText,
    Widget? suffix,
  }) => InputDecoration(
    labelText: label,
    errorText: errorText,
    filled: true,
    fillColor: surface,
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );

  TextStyle _text(double size, {FontWeight? weight, Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? muted,
        height: 1.45,
      );

  Widget _spinner() => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: bad),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Delete your account',
                    style: _text(18, weight: FontWeight.w800, color: ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'This permanently removes your profile, connected Google tokens and '
              'synced data. If you are the only member of your workspace, the '
              'workspace is deleted too. Invoices and payment records are kept '
              'only as long as the law requires.',
              style: _text(13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirm,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: _decoration('Type DELETE to confirm'),
            ),
            const SizedBox(height: 12),
            if (_useCode) ..._codeSection() else ..._passwordSection(),
            TextButton(
              onPressed: _busy ? null : () => openPublicPage('/delete-account'),
              child: const Text('Prefer email? See the deletion page'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _passwordSection() {
    return [
      TextField(
        controller: _password,
        obscureText: _hide,
        onChanged: (_) {
          if (_passwordError != null) {
            setState(() => _passwordError = null);
          }
        },
        decoration: _decoration(
          'Your password',
          errorText: _passwordError,
          suffix: IconButton(
            tooltip: _hide ? 'Show password' : 'Hide password',
            icon: Icon(
              _hide ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: muted,
            ),
            onPressed: () => setState(() => _hide = !_hide),
          ),
        ),
      ),
      const SizedBox(height: 14),
      SheetNotice(_notice, error: _noticeIsError),
      FilledButton(
        onPressed: (_busy || !_confirmed) ? null : _withPassword,
        style: FilledButton.styleFrom(backgroundColor: bad),
        child: _busy ? _spinner() : const Text('Delete my account'),
      ),
      const SizedBox(height: 4),
      // No password (an account made with a mobile number): a code on WhatsApp
      // confirms it instead.
      if (_full != null)
        TextButton.icon(
          onPressed: _busy ? null : () => _switchTo(code: true),
          icon: const Icon(Icons.sms_outlined, size: 20),
          label: const Text('No password? Get a code on WhatsApp'),
        ),
      // Google confirmation exists only where Google sign-in does
      // (platform_rules.dart). On iOS the password confirms; an account
      // made with Google can set one through "Forgot password".
      if (googleSignInAvailable)
        TextButton.icon(
          onPressed: (_busy || !_confirmed) ? null : _withGoogle,
          icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
          label: const Text('I signed in with Google: confirm with Google'),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Signed up with Google and never set a password? Use "Forgot password" on the sign-in screen to set one first.',
            textAlign: TextAlign.center,
            style: _text(11.5),
          ),
        ),
    ];
  }

  List<Widget> _codeSection() {
    final complete = otpCodeComplete(_code.text);
    return [
      Text(
        _sent
            ? 'We sent a 6-digit code on WhatsApp to ${formatOtpPhone(_full!)}.'
            : 'To confirm it is you, we will send a 6-digit code on WhatsApp '
                  'to ${formatOtpPhone(_full!)}.',
        style: _text(12.5, color: ink),
      ),
      const SizedBox(height: 12),
      if (_sent) ...[
        TextField(
          controller: _code,
          focusNode: _codeFocus,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: ink,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(kOtpCodeLength),
          ],
          onChanged: (_) => setState(() {}),
          decoration: _decoration('6-digit code'),
        ),
        const SizedBox(height: 14),
      ],
      SheetNotice(_notice, error: _noticeIsError),
      FilledButton(
        onPressed: _sent
            ? ((_busy || !_confirmed || !complete) ? null : _withCode)
            : ((_busy || !_confirmed) ? null : _sendCode),
        style: FilledButton.styleFrom(backgroundColor: bad),
        child: _busy
            ? _spinner()
            : Text(_sent ? 'Delete my account' : 'Send code to WhatsApp'),
      ),
      const SizedBox(height: 4),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _switchTo(code: false),
            child: const Text('Use my password instead'),
          ),
          if (_sent)
            TextButton(
              onPressed: (_busy || _cooldown > 0) ? null : _sendCode,
              child: Text(
                _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend code',
              ),
            ),
        ],
      ),
    ];
  }
}
