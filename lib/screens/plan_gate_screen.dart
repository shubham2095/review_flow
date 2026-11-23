import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/platform_rules.dart';
import '../services/products.dart';
import '../services/session.dart';
import '../services/web_handoff.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/royal_backdrop.dart';

/// The big title and the line under it on the plan page.
///
/// A product that the plan does not include: "Unlock WhatsApp". No plan at
/// all: "Activate your workspace".
({String title, String subtitle}) planGateHeadline(
  Product? product,
  bool hasPlan,
) {
  if (product != null && hasPlan) {
    return (
      title: 'Unlock ${product.short}',
      subtitle: '${product.title} is not included in your current plan.',
    );
  }
  return (
    title: 'Activate your workspace',
    subtitle: 'This account has no active plan yet.',
  );
}

/// The three steps shown on Android, where the plan is bought on the website.
List<({String title, String text})> planGateSteps(Product? product) => [
  (title: 'Open the website', text: 'We sign you in, no password needed.'),
  (
    title: 'Choose a plan',
    text: product == null
        ? 'Pick the plan that suits your business.'
        : 'Pick one that includes ${product.short}.',
  ),
  (
    title: 'Come back here',
    text: 'This page checks and switches it on for you.',
  ),
];

/// Shown when the plan does not open what the person tapped: no plan at all,
/// or a plan without that product. On Android a button opens the website,
/// where the plan is bought; iOS shows plain wording only. The page re-checks
/// the plan whenever the app comes back to the foreground.
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
  bool _opening = false;

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

  /// Opens the website (signed in) on the billing page, where a plan is
  /// bought. When the person comes back, the page checks the plan again by
  /// itself and opens what the new plan includes.
  Future<void> _openWeb() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openInWeb(next: '/billing');
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.logout();
    if (mounted) widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.current;
    final name = user?.displayName.trim() ?? '';
    final first = name.isEmpty ? '' : name.split(' ').first;
    final p = widget.product;
    final hasPlan = user?.hasPlan ?? false;
    final productLocked = p != null && hasPlan;
    final headline = planGateHeadline(p, hasPlan);
    final plan = user?.planName?.trim() ?? '';
    // With no plan at all, show a taste of both products.
    final benefits = p != null
        ? p.benefits
        : [
            ...Product.gbp.benefits.take(2),
            ...Product.whatsapp.benefits.take(2),
          ];
    const tones = [brand, royalViolet, good, warn];

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
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeIn(
                    child: _Hero(product: p, locked: productLocked),
                  ),
                  const SizedBox(height: 22),
                  FadeIn(
                    delay: 80,
                    child: Column(
                      children: [
                        if (first.isNotEmpty)
                          Text(
                            'Hi $first',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: royalGold,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Semantics(
                          header: true,
                          child: Text(
                            headline.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          headline.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.white70,
                          ),
                        ),
                        if (productLocked && plan.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Pill(
                                icon: Icons.workspace_premium_rounded,
                                text: 'Your plan: $plan',
                                color: royalGold,
                              ),
                              _Pill(
                                icon: Icons.lock_rounded,
                                text: '${p.short} not included',
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  FadeIn(
                    delay: 160,
                    child: _Card(
                      title: p == null
                          ? 'What switches on'
                          : 'What ${p.short} gives you',
                      children: [
                        for (var i = 0; i < benefits.length; i++)
                          _Benefit(
                            icon: benefits[i].$1,
                            color: tones[i % tones.length],
                            text: benefits[i].$2,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeIn(
                    delay: 240,
                    child: _Card(
                      title: planPurchaseLinkAllowed
                          ? 'How to get it'
                          : 'To switch it on',
                      children: [
                        if (planPurchaseLinkAllowed) ...[
                          for (final (i, s) in planGateSteps(p).indexed)
                            _Step(
                              number: i + 1,
                              title: s.title,
                              text: s.text,
                              last: i == 2,
                            ),
                          const SizedBox(height: 18),
                          _GradientButton(
                            label: 'Get a plan on the website',
                            icon: Icons.open_in_new_rounded,
                            busy: _opening,
                            onPressed: _openWeb,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Opens the Eydia website in your browser, '
                              'signed in.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                height: 1.4,
                                color: muted,
                              ),
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              productLocked
                                  ? 'Your current plan does not include ${p.title}. If your business already uses it, sign out and sign in with that account.'
                                  : 'This account does not have an active plan yet. Once a plan is active on it, everything above switches on. If your business already uses Eydia, sign out and sign in with that account.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                height: 1.5,
                                color: inkSoft,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _checking ? null : _check,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(
                              color: royalIndigo.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _checking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('Check again'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeIn(
                    delay: 320,
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
                                'Signed in as ${user?.email ?? ''}',
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

/// The product's icon in a glowing gradient tile, with a small lock when a
/// plan exists but does not include it.
class _Hero extends StatelessWidget {
  const _Hero({required this.product, required this.locked});

  final Product? product;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final tile = SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glow behind the tile.
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  royalGold.withValues(alpha: 0.35),
                  royalGold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [royalIndigo, royalViolet, Color(0xFF5B3FD0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: royalGold.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: royalGold.withValues(alpha: 0.30),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: product == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/eydia_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : Icon(product!.icon, size: 44, color: Colors.white),
          ),
          if (locked)
            Positioned(
              right: 14,
              bottom: 12,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: royalGold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: royalIndigo,
                ),
              ),
            ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: reduce
          ? tile
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutBack,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: tile,
            ),
    );
  }
}

/// A small rounded tag on the dark background.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A white card with a gold-underlined heading.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
          Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 3,
            margin: const EdgeInsets.only(top: 6, bottom: 16),
            decoration: BoxDecoration(
              color: royalGold,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          ...children,
        ],
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One numbered step, joined to the next by a thin line.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.text,
    required this.last,
  });

  final int number;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Step $number. $title. $text',
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [royalIndigo, royalViolet],
                    ),
                  ),
                  child: Text(
                    '$number',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: royalIndigo.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        height: 1.35,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The main action: a gradient pill with an icon, and a spinner while busy.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: busy
                ? [
                    royalIndigo.withValues(alpha: 0.6),
                    royalViolet.withValues(alpha: 0.6),
                  ]
                : const [royalIndigo, royalViolet],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: royalIndigo.withValues(alpha: busy ? 0.1 : 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: busy ? null : onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(icon, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
