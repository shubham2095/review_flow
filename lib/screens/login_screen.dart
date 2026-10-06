import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';

const _navy = Color(0xFF0E1530);
const _royal = Color(0xFF1E2A6B);
const _violet = Color(0xFF3B2A8C);
const _gold = Color(0xFFD4AF37);

/// Native login and sign-up. Google login uses the phone's Google account,
/// email login uses /api/login, and sign-up uses /api/register.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
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
    if (email.isEmpty || password.isEmpty) {
      _snack('Email and password are required');
      return;
    }
    if (_signUp) {
      if (_name.text.trim().isEmpty) {
        _snack('Name is required');
        return;
      }
      if (password.length < 8) {
        _snack('Password must be at least 8 characters');
        return;
      }
      await _run(() => AuthService.register(_name.text.trim(), email, password));
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

  InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: surface,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _royal, width: 1.4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_navy, _royal, _violet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1.2),
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
                    child: Image.asset('assets/images/eydia_logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 22),
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
                Text(
                  _signUp ? 'Create your account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to manage your business presence',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
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
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _google,
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                        label: Text(
                          'Continue with Google',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: ink,
                          side: const BorderSide(color: Color(0xFFDDE2EE)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFE6EAF2))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'or continue with email',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFE6EAF2))),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_signUp) ...[
                        TextField(controller: _name, decoration: _dec('Full name')),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _dec('Email address'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _hidePassword,
                        onSubmitted: (_) => _submit(),
                        decoration: _dec(
                          _signUp ? 'Password (min 8 characters)' : 'Password',
                          suffix: IconButton(
                            tooltip: _hidePassword ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _hidePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: muted,
                            ),
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _GradientButton(
                        label: _signUp ? 'Create account' : 'Sign in',
                        busy: _busy,
                        onTap: _busy ? null : _submit,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
                        child: Text(
                          _signUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up",
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _royal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Secure sign-in for your Eydia account',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.busy, required this.onTap});

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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
