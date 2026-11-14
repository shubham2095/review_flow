import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/products.dart';
import '../services/push_service.dart';
import '../services/session.dart';
import '../theme/brand.dart';
import '../widgets/fade_in.dart';
import '../widgets/royal_backdrop.dart';
import 'billing_screen.dart';
import 'profile_screen.dart';

/// The first screen after sign-in: one box per product. A box the plan
/// includes opens that product; any other box explains that a plan with it is
/// needed. Nothing is sold here or linked out to buy.
class ProductHub extends StatefulWidget {
  const ProductHub({
    super.key,
    required this.onOpen,
    required this.onLocked,
    required this.onSignedOut,
  });

  final ValueChanged<Product> onOpen;
  final ValueChanged<Product> onLocked;
  final VoidCallback onSignedOut;

  @override
  State<ProductHub> createState() => _ProductHubState();
}

class _ProductHubState extends State<ProductHub> with WidgetsBindingObserver {
  DateTime? _lastBack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushService.target.addListener(_onPush);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Notifications: register this phone (and ask once, politely).
      PushService.start(context).then((_) => _onPush(), onError: (_) {});
      _onPush();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushService.target.removeListener(_onPush);
    super.dispose();
  }

  /// Back from a plan bought on the web: pick up the new plan without a pull.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      await Session.refresh();
    } catch (_) {
      // Keep what is on screen.
    }
  }

  /// A tapped notification while no product is open: open the product it is
  /// about. The product itself then goes to the exact page.
  void _onPush() {
    final t = PushService.target.value;
    if (t == null || !mounted) return;
    final product = t.isReview ? Product.gbp : Product.whatsapp;
    if (product.unlockedFor(Session.current)) {
      widget.onOpen(product);
    } else {
      PushService.target.value = null;
      widget.onLocked(product);
    }
  }

  void _tap(Product p) {
    HapticFeedback.selectionClick();
    if (p.unlockedFor(Session.current)) {
      widget.onOpen(p);
    } else {
      widget.onLocked(p);
    }
  }

  void _openPage(String title, Widget body) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            foregroundColor: ink,
          ),
          body: body,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await AuthService.logout();
    if (mounted) widget.onSignedOut();
  }

  /// A second press within two seconds leaves the app (this is the first screen).
  void _onBack() {
    final now = DateTime.now();
    final last = _lastBack;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: RoyalBackdrop(
          child: SafeArea(
            child: ValueListenableBuilder<AppUser?>(
              valueListenable: Session.user,
              builder: (context, user, _) {
                final name = user?.name.trim() ?? '';
                final first = name.isEmpty ? '' : name.split(' ').first;
                final hasPlan = user?.hasPlan ?? false;
                return RefreshIndicator(
                  color: brand,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                    children: [
                      FadeIn(
                        child: Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: royalGold.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/eydia_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeIn(
                        delay: 60,
                        child: Column(
                          children: [
                            Text(
                              first.isEmpty ? 'Welcome to Eydia' : 'Welcome, $first',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasPlan
                                  ? 'Choose where you want to work'
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
                      const SizedBox(height: 24),
                      for (var i = 0; i < Product.values.length; i++)
                        FadeIn(
                          delay: 120 + i * 80,
                          child: _ProductCard(
                            product: Product.values[i],
                            unlocked: Product.values[i].unlockedFor(user),
                            hasPlan: hasPlan,
                            onTap: () => _tap(Product.values[i]),
                          ),
                        ),
                      const SizedBox(height: 10),
                      FadeIn(
                        delay: 320,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          children: [
                            _FooterButton(
                              Icons.person_rounded,
                              'My profile',
                              () => _openPage(
                                'My Profile',
                                ProfileScreen(onSignedOut: widget.onSignedOut),
                              ),
                            ),
                            _FooterButton(
                              Icons.workspace_premium_rounded,
                              'Plan and credits',
                              () => _openPage(
                                'Plan and credits',
                                const BillingScreen(),
                              ),
                            ),
                            _FooterButton(
                              Icons.logout_rounded,
                              'Sign out',
                              _signOut,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.unlocked,
    required this.hasPlan,
    required this.onTap,
  });

  final Product product;
  final bool unlocked;
  final bool hasPlan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        button: true,
        label: unlocked
            ? 'Open ${product.title}'
            : '${product.title}, not in your plan',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: unlocked
                          ? const LinearGradient(
                              colors: [royalIndigo, royalViolet],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: unlocked ? null : muted.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      product.icon,
                      size: 28,
                      color: unlocked ? Colors.white : muted,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: unlocked ? ink : const Color(0xFF4A5468),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          product.subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            height: 1.35,
                            color: muted,
                          ),
                        ),
                        if (!unlocked) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: warn.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_rounded, size: 12, color: warn),
                                const SizedBox(width: 4),
                                Text(
                                  hasPlan ? 'Not in your plan' : 'Plan needed',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: warn,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    unlocked
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.lock_outline_rounded,
                    size: unlocked ? 16 : 20,
                    color: unlocked ? brand : muted,
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

class _FooterButton extends StatelessWidget {
  const _FooterButton(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white70),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
