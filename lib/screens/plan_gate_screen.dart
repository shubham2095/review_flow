import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/platform_rules.dart';
import '../services/products.dart';
import '../services/session.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/royal_backdrop.dart';

/// Shown when the plan does not open what the person tapped: no plan at all,
/// or a plan without that product. The app never sells anything: the page only
/// says to get a plan on the website and sign in again, and re-checks the plan
/// whenever the app comes back to the foreground.
class PlanGateScreen extends StatefulWidget {
  const PlanGateScreen({
    super.key,
    required this.onUnlocked,
    required this.onSignedOut,
    this.product,
    this.onBack,
  });

  final VoidCallback onUnlocked;
  final VoidCallback onSignedOut;

  /// The product that was tapped. Null: the whole workspace is locked.
  final Product? product;

  /// Shows a back arrow that returns to the product boxes.
  final VoidCallback? onBack;

  @override
  State<PlanGateScreen> createState() => _PlanGateScreenState();
}

class _PlanGateScreenState extends State<PlanGateScreen>
    with WidgetsBindingObserver {
  bool _checking = false;

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
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }


  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final user = await Session.refresh();
      if (!mounted) return;
      final p = widget.product;
      final open = p == null ? user.hasPlan : p.unlockedFor(user);
      if (open) {
        HapticFeedback.mediumImpact();
        widget.onUnlocked();
      } else if (!silent) {
        _snack(
          p != null && user.hasPlan
              ? 'Your plan does not include ${p.title} yet.'
              : 'This account does not have an active plan yet.',
        );
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
    final p = widget.product;
    final hasPlan = Session.current?.hasPlan ?? false;
    final productLocked = p != null && hasPlan;
    final benefits = (p ?? Product.gbp).benefits;
    const tones = [brand, brandDeep, good, warn];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.onBack == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
              leading: BackButton(onPressed: widget.onBack),
            ),
      body: RoyalBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeIn(
                    child: Container(
                      width: 84,
                      height: 84,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: royalGold.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: royalGold.withValues(alpha: 0.25),
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
                          productLocked
                              ? '${p.title} is not in your plan'
                              : 'Your workspace is not active yet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: royalGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FadeIn(
                    delay: 160,
                    child: Container(
                      padding: const EdgeInsets.all(22),
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
                          Text(
                            p == null ? 'What switches on' : 'What ${p.short} gives you',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < benefits.length; i++)
                            _Benefit(
                              icon: benefits[i].$1,
                              color: tones[i % tones.length],
                              text: benefits[i].$2,
                            ),
                          const SizedBox(height: 16),
                          Text(
                            productLocked
                                ? (isIos
                                      ? 'Your current plan does not include ${p.title}. If your business already uses it, sign out and sign in with that account.'
                                      : 'Your current plan does not include ${p.title}. Open the Eydia website, choose a plan that includes it, then come back and sign in again.')
                                : (isIos
                                      ? 'This account does not have an active plan yet. Once a plan is active on it, everything above switches on. If your business already uses Eydia, sign out and sign in with that account.'
                                      : 'This account has no active plan yet. Open the Eydia website, buy a plan there, then come back and sign in again.'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              height: 1.45,
                              color: muted,
                            ),
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
                                : const Text('Check again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeIn(
                    delay: 260,
                    child: Column(
                      children: [
                        Row(
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
                                'Signed in as ${Session.current?.email ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.35,
                color: const Color(0xFF4A5468),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
