import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session.dart';

const _navy = Color(0xFF0E1530);
const _royal = Color(0xFF1E2A6B);
const _violet = Color(0xFF3B2A8C);
const _gold = Color(0xFFD4AF37);

/// Shown when the account has no active plan. Plans are bought on the web
/// (Google Play does not allow Razorpay checkout inside the app), so this screen
/// opens the web app already signed in and re-checks the plan when the user returns.
class PlanGateScreen extends StatefulWidget {
  const PlanGateScreen({
    super.key,
    required this.onUnlocked,
    required this.onSignedOut,
  });

  final VoidCallback onUnlocked;
  final VoidCallback onSignedOut;

  @override
  State<PlanGateScreen> createState() => _PlanGateScreenState();
}

class _PlanGateScreenState extends State<PlanGateScreen>
    with WidgetsBindingObserver {
  bool _opening = false;
  bool _checking = false;
  bool _wentToWeb = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToWeb) {
      _check(silent: true);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openWeb() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final url = await AuthService.webSessionUrl();
      _wentToWeb = true;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final user = await Session.refresh();
      if (!mounted) return;
      if (user.hasPlan) {
        widget.onUnlocked();
      } else if (!silent) {
        _snack('No active plan yet. Finish the payment on the web first.');
      }
    } catch (e) {
      if (!silent) _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.logout();
    if (mounted) widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final name = Session.current?.name.trim() ?? '';
    final first = name.isEmpty ? '' : name.split(' ').first;

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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/eydia_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    first.isEmpty ? 'Welcome to Eydia' : 'Welcome, $first',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a plan to unlock your workspace',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: _gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Your account is ready. Reviews, posts, insights and AI tools '
                          'switch on as soon as a plan is active.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            height: 1.5,
                            color: const Color(0xFF4A5468),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Payment is completed securely on the web. '
                          "You'll already be signed in when it opens.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            height: 1.5,
                            color: const Color(0xFF4A5468),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _opening ? null : _openWeb,
                          icon: _opening
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Continue on web'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _checking ? null : _check,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _checking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text("I've subscribed, check again"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _signOut,
                    child: Text(
                      'Sign out',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
