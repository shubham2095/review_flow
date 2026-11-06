import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/password_rules.dart';
import '../widgets/royal_backdrop.dart';
import '../widgets/sheet_notice.dart';

const _navy = Color(0xFF0E1530);
const _royal = Color(0xFF1E2A6B);
const _violet = Color(0xFF3B2A8C);
const _gold = Color(0xFFD4AF37);

/// Native login and sign-up. Google login uses the phone's Google account,
/// email login uses /auth/login, and sign-up uses /auth/register.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _company = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _hidePassword = true;

  /// Problems found on the last attempt, by field. A message goes away as soon
  /// as that field is edited.
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    for (final entry in {
      'company': _company,
      'name': _name,
      'email': _email,
      'password': _password,
    }.entries) {
      entry.value.addListener(() {
        if (_errors.containsKey(entry.key)) {
          setState(() => _errors.remove(entry.key));
        }
      });
    }
  }

  Future<void> _forgotPassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ForgotPasswordSheet(initialEmail: _email.text.trim()),
    );
  }

  @override
  void dispose() {
    _company.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) widget.onLoggedIn();
    } on SignInCancelled {
      // The person closed the Google chooser: nothing to report.
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    final errors = <String, String>{};
    if (email.isEmpty) {
      errors['email'] = 'Enter your email address.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors['email'] = 'Enter a valid email, like name@example.com.';
    }
    if (password.isEmpty) {
      errors['password'] = 'Enter your password.';
    }
    if (_signUp) {
      if (_company.text.trim().isEmpty) {
        errors['company'] = 'Enter your business name.';
      }
      if (_name.text.trim().isEmpty) errors['name'] = 'Enter your name.';
      // Signing in must accept any existing password; only a new one is held
      // to the server's rule.
      final problem = PasswordRules.problem(password);
      if (password.isNotEmpty && problem != null) errors['password'] = problem;
    }
    if (errors.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _errors = errors);
      return;
    }

    if (_signUp) {
      await _run(
        () => AuthService.register(
          companyName: _company.text.trim(),
          name: _name.text.trim(),
          email: email,
          password: password,
        ),
      );
    } else {
      await _run(() => AuthService.loginWithEmail(email, password));
    }
  }

  Future<void> _google() async {
    await _run(() async {
      final idToken = await AuthService.googleIdToken();
      await AuthService.loginWithGoogle(idToken);
    });
  }

  InputDecoration _dec(String label, {Widget? suffix, String? errorKey}) => InputDecoration(
    errorText: errorKey == null ? null : _errors[errorKey],
    errorMaxLines: 2,
    labelText: label,
    filled: true,
    fillColor: surface,
    suffixIcon: suffix,
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
      borderSide: const BorderSide(color: _royal, width: 1.4),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RoyalBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            child: Column(
              children: [
                const SizedBox(height: 12),
                FadeIn(
                  child: Container(
                    width: 88,
                    height: 88,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/eydia_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FadeIn(
                  delay: 80,
                  child: Column(
                    children: [
                      Text(
                        'EYDIA',
                        style: GoogleFonts.cinzel(
                          color: _gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _signUp ? 'Create your account' : 'Welcome back',
                          key: ValueKey(_signUp),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _signUp
                            ? 'Start managing your Google presence in minutes'
                            : 'Sign in to manage your business presence',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                FadeIn(
                  delay: 160,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ModeToggle(
                          signUp: _signUp,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _signUp = v),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _google,
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 30,
                          ),
                          label: Text(
                            'Continue with Google',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            foregroundColor: ink,
                            side: const BorderSide(color: Color(0xFFDDE2EE)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'New to Eydia? Google creates your account automatically.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Color(0xFFE6EAF2)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'or continue with email',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Color(0xFFE6EAF2)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          alignment: Alignment.topCenter,
                          child: _signUp
                              ? Column(
                                  children: [
                                    TextField(
                                      controller: _company,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: _dec('Business name', errorKey: 'company'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _name,
                                      textInputAction: TextInputAction.next,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      autofillHints: const [AutofillHints.name],
                                      decoration: _dec('Full name', errorKey: 'name'),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: _dec('Email address', errorKey: 'email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _busy ? null : _submit(),
                          decoration: _dec(
                            'Password',
                            errorKey: 'password',
                            suffix: IconButton(
                              tooltip: _hidePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: muted,
                              ),
                              onPressed: () => setState(
                                () => _hidePassword = !_hidePassword,
                              ),
                            ),
                          ),
                        ),
                        // New password: show the rule as it is met. Existing
                        // account: a way back in when the password is forgotten.
                        if (_signUp)
                          ListenableBuilder(
                            listenable: _password,
                            builder: (context, _) => Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4, top: 2),
                                child: PasswordRulesView(password: _password.text),
                              ),
                            ),
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _forgotPassword,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 44),
                              ),
                              child: Text(
                                'Forgot password?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _royal,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _GradientButton(
                          label: _signUp ? 'Create account' : 'Sign in',
                          busy: _busy,
                          onTap: _busy ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FadeIn(
                  delay: 260,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Secure sign-in for your Eydia account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sign in / Create account switch shown at the top of the card.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.signUp, required this.onChanged});

  final bool signUp;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final selected = signUp == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onChanged == null ? null : () => onChanged!(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _navy.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? _royal : muted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [tab('Sign in', false), tab('Create account', true)],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null && !busy ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_royal, _violet]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _royal.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for the account email and has the server send a reset link. The link
/// opens a page on the web where the new password is chosen.
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _emailError;
  String? _notice;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  /// The server allows only a few requests a minute: ask the person to wait
  /// rather than let them hit that wall.
  void _startCooldown() {
    _cooldown = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      HapticFeedback.mediumImpact();
      setState(() => _emailError = 'Enter the email you signed up with.');
      return;
    }
    setState(() {
      _busy = true;
      _emailError = null;
      _notice = null;
    });
    try {
      await AuthService.forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice = friendlyException(e).message;
      });
    }
  }

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
            Text(
              _sent ? 'Check your email' : 'Reset your password',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _sent
                  ? 'If ${_email.text.trim()} has an Eydia account, we have sent a link to reset the password. Open it, choose a new password, then come back and sign in. It can take a minute to arrive, and may be in spam.'
                  : "Enter your account email and we'll send you a link to choose a new password.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.45,
                color: muted,
              ),
            ),
            const SizedBox(height: 16),
            if (!_sent) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
                onSubmitted: (_) => _busy ? null : _send(),
                decoration: InputDecoration(
                  labelText: 'Email address',
                  errorText: _emailError,
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            SheetNotice(_notice),
            FilledButton(
              onPressed: (_busy || _cooldown > 0) ? null : _send,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _cooldown > 0
                          ? 'Send again in ${_cooldown}s'
                          : (_sent ? 'Send the link again' : 'Send reset link'),
                    ),
            ),
            if (_sent)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to sign in'),
              ),
          ],
        ),
      ),
    );
  }
}
