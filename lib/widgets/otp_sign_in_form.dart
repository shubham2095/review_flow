import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/otp_login.dart';
import '../theme/brand.dart';
import 'gradient_button.dart';
import 'otp_code_boxes.dart';
import 'sheet_notice.dart';

typedef OtpVerify =
    Future<void> Function(String phone, String code, {required bool register});

const _whatsappGreen = Color(0xFF25D366);

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

/// Shows the number as "98765 43210" while it is typed, and cleans a pasted
/// "+91 ..." down to the ten digits (the +91 is already in front of the field).
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    int digits(String s) => s.replaceAll(RegExp(r'\D'), '').length;
    final pasted = digits(newValue.text) - digits(oldValue.text) > 1;
    final text = formatPhoneInput(newValue.text, pasted: pasted);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
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

  /// The last code was refused: the boxes show red until the next digit.
  bool _codeWrong = false;
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
        _codeWrong = false;
        _noticeIsError = false;
        // A development server echoes the code so it can be tested without
        // WhatsApp; a real one never does.
        _notice = result.devCode != null
            ? 'Test code: ${result.devCode}'
            : (firstSend ? null : 'A new code is on its way.');
      });
      _code.clear();
      _startCooldown();
      if (firstSend) {
        // The code boxes appear on the next frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _codeFocus.requestFocus();
        });
      }
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
      final refused = error.statusCode == 422;
      if (refused) {
        _code.clear();
        HapticFeedback.mediumImpact();
      }
      setState(() {
        _busy = false;
        _codeWrong = refused;
        _noticeIsError = true;
        _notice = otpErrorMessage(error);
      });
      if (refused) _codeFocus.requestFocus();
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _sentTo = null;
      _cooldown = 0;
      _notice = null;
      _codeWrong = false;
      _code.clear();
    });
  }

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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: sentTo == null
            ? KeyedSubtree(key: const ValueKey('number'), child: _numberStep())
            : KeyedSubtree(
                key: const ValueKey('code'),
                child: _codeStep(sentTo),
              ),
      ),
    );
  }

  Widget _numberStep() {
    final hint = widget.register
        ? "We'll send a 6-digit code on WhatsApp. You can add your business "
              'name and email later, from your profile.'
        : "We'll send a 6-digit code on WhatsApp.";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [_PhoneFormatter()],
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: ink,
          ),
          onChanged: (_) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            labelText: 'Mobile number',
            errorText: _phoneError,
            errorMaxLines: 2,
            filled: true,
            fillColor: surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone_iphone_rounded,
                    size: 20,
                    color: muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+91',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: const Color(0xFFD5DAE6),
                  ),
                ],
              ),
            ),
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
              borderSide: const BorderSide(color: royalIndigo, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: _whatsappGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(hint, style: _text(12))),
          ],
        ),
        const SizedBox(height: 18),
        SheetNotice(_notice, error: _noticeIsError),
        GradientButton(
          label: 'Send code',
          icon: Icons.arrow_forward_rounded,
          busy: _busy,
          onPressed: _busy ? null : _send,
        ),
      ],
    );
  }

  Widget _codeStep(String sentTo) {
    final complete = otpCodeComplete(_code.text);
    final shown = formatOtpPhone(sentTo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _whatsappGreen.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_chat_read_rounded,
              size: 28,
              color: Color(0xFF128C4A),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enter the code',
          textAlign: TextAlign.center,
          style: _text(20, weight: FontWeight.w800, color: ink),
        ),
        const SizedBox(height: 6),
        Text(
          widget.register
              ? 'Code sent on WhatsApp to $shown'
              : 'If $shown has an Eydia account, a code is on its way on '
                    'WhatsApp.',
          textAlign: TextAlign.center,
          style: _text(12.5),
        ),
        const SizedBox(height: 20),
        OtpCodeBoxes(
          controller: _code,
          focusNode: _codeFocus,
          enabled: !_busy,
          hasError: _codeWrong,
          onChanged: (value) {
            setState(() => _codeWrong = false);
            // Sign in as soon as the last digit is in (typed or autofilled).
            if (otpCodeComplete(value)) _verify();
          },
        ),
        const SizedBox(height: 16),
        SheetNotice(_notice, error: _noticeIsError),
        GradientButton(
          label: widget.register
              ? 'Verify & create account'
              : 'Verify & sign in',
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: (_busy || !complete) ? null : _verify,
        ),
        const SizedBox(height: 6),
        // A Wrap, not a Row: with large text the two buttons go on two lines
        // instead of running off the edge.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : _changeNumber,
              icon: const Icon(Icons.edit_rounded, size: 16),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                foregroundColor: royalIndigo,
              ),
              label: Text(
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
