import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/otp_login.dart';
import '../theme/brand.dart';
import 'sheet_notice.dart';

typedef OtpRequest =
    Future<OtpRequestResult> Function(String phone, {required bool register});
typedef OtpVerify =
    Future<void> Function(String phone, String code, {required bool register});

/// Sign in with a mobile number: type the number, get a 6-digit code on
/// WhatsApp, type the code. [register] is for a new number (the server then
/// makes the account); without it only numbers that already have an account
/// get in. [request] and [verify] are the server calls, replaceable in tests.
class OtpSignInForm extends StatefulWidget {
  const OtpSignInForm({
    super.key,
    required this.onSignedIn,
    this.register = false,
    OtpRequest? request,
    OtpVerify? verify,
  }) : request = request ?? _defaultRequest,
       verify = verify ?? _defaultVerify;

  final VoidCallback onSignedIn;
  final bool register;
  final OtpRequest request;
  final OtpVerify verify;

  static Future<OtpRequestResult> _defaultRequest(
    String phone, {
    required bool register,
  }) => AuthService.requestOtp(phone, register: register);

  static Future<void> _defaultVerify(
    String phone,
    String code, {
    required bool register,
  }) => AuthService.verifyOtp(phone, code, register: register);

  @override
  State<OtpSignInForm> createState() => _OtpSignInFormState();
}

class _OtpSignInFormState extends State<OtpSignInForm> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  /// The number the code was sent to (country code first, digits only). Null
  /// while the number is still being typed.
  String? _sentTo;
  bool _busy = false;
  String? _phoneError;
  String? _notice;
  bool _noticeIsError = true;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
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

  Future<void> _send() async {
    if (_busy) return;
    final full = normalizeOtpPhone(_phone.text);
    if (full == null) {
      HapticFeedback.mediumImpact();
      setState(
        () => _phoneError =
            'Enter your 10-digit mobile number, like 98765 43210.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _phoneError = null;
      _notice = null;
    });
    try {
      final result = await widget.request(full, register: widget.register);
      if (!mounted) return;
      final firstSend = _sentTo == null;
      setState(() {
        _busy = false;
        _sentTo = full;
        _noticeIsError = false;
        // A development server echoes the code so it can be tested without
        // WhatsApp; a real one never does.
        _notice = result.devCode != null
            ? 'Test code: ${result.devCode}'
            : (firstSend ? null : 'A new code is on its way.');
      });
      _code.clear();
      _startCooldown();
      if (firstSend) _codeFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      final error = friendlyException(e);
      setState(() {
        _busy = false;
        _noticeIsError = true;
        _notice = otpErrorMessage(error);
      });
    }
  }

  Future<void> _verify() async {
    final to = _sentTo;
    final code = _code.text;
    if (_busy || to == null || !otpCodeComplete(code)) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await widget.verify(to, code, register: widget.register);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSignedIn();
    } catch (e) {
      if (!mounted) return;
      final error = friendlyException(e);
      // A wrong code is retyped from scratch; a network problem keeps it.
      if (error.statusCode == 422) _code.clear();
      setState(() {
        _busy = false;
        _noticeIsError = true;
        _notice = otpErrorMessage(error);
      });
      if (error.statusCode == 422) _codeFocus.requestFocus();
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _sentTo = null;
      _cooldown = 0;
      _notice = null;
      _code.clear();
    });
  }

  InputDecoration _decoration(String label, {String? errorText}) =>
      InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 2,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: royalIndigo, width: 1.4),
        ),
      );

  ButtonStyle get _buttonStyle => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    backgroundColor: royalIndigo,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  Widget _spinner() => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );

  TextStyle _text(double size, {FontWeight? weight, Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? muted,
        height: 1.4,
      );

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: sentTo == null ? _numberStep() : _codeStep(sentTo),
    );
  }

  Widget _numberStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-]')),
            LengthLimitingTextInputFormatter(18),
          ],
          onChanged: (_) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
          onSubmitted: (_) => _send(),
          decoration: _decoration(
            'Mobile number',
            errorText: _phoneError,
          ).copyWith(prefixIcon: const Icon(Icons.phone_iphone_rounded)),
        ),
        const SizedBox(height: 8),
        Text(
          "We'll send a 6-digit code on WhatsApp. +91 is added for you.",
          style: _text(11.5),
        ),
        const SizedBox(height: 14),
        SheetNotice(_notice, error: _noticeIsError),
        FilledButton(
          onPressed: _busy ? null : _send,
          style: _buttonStyle,
          child: _busy
              ? _spinner()
              : Text(
                  'Send code',
                  style: _text(
                    15,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _codeStep(String sentTo) {
    final complete = otpCodeComplete(_code.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.register
              ? 'Code sent on WhatsApp to ${formatOtpPhone(sentTo)}'
              : 'If ${formatOtpPhone(sentTo)} has an Eydia account, a code is '
                    'on its way on WhatsApp.',
          style: _text(12.5, color: ink),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          focusNode: _codeFocus,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
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
          onChanged: (value) {
            setState(() {});
            // Sign in as soon as the last digit is in (typed or autofilled).
            if (otpCodeComplete(value)) _verify();
          },
          onSubmitted: (_) => _verify(),
          decoration: _decoration('6-digit code'),
        ),
        const SizedBox(height: 14),
        SheetNotice(_notice, error: _noticeIsError),
        FilledButton(
          onPressed: (_busy || !complete) ? null : _verify,
          style: _buttonStyle,
          child: _busy
              ? _spinner()
              : Text(
                  widget.register
                      ? 'Verify & create account'
                      : 'Verify & sign in',
                  style: _text(
                    15,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        // A Wrap, not a Row: with large text the two buttons go on two lines
        // instead of running off the edge.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: _busy ? null : _changeNumber,
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              child: Text(
                'Change number',
                style: _text(12.5, weight: FontWeight.w700, color: royalIndigo),
              ),
            ),
            TextButton(
              onPressed: (_busy || _cooldown > 0) ? null : _send,
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              child: Text(
                _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend code',
                style: _text(
                  12.5,
                  weight: FontWeight.w700,
                  color: _cooldown > 0 ? muted : royalIndigo,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
