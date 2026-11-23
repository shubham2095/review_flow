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
import '../widgets/wa_ui.dart';
import 'billing_screen.dart';
import 'profile_screen.dart';

/// "Good morning", "Good afternoon" or "Good evening" for an hour of the day.
String hubGreeting(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// What each product covers, as short words on its box.
const hubHighlights = <Product, List<String>>{
  Product.gbp: ['Reviews', 'Posts', 'Photos', 'Insights'],
  Product.whatsapp: ['Chats', 'Contacts', 'Campaigns', 'Chatbots'],
};

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
      // The plan may have changed since the last look (an admin gave or took
      // a product): read it again every time the boxes appear, so a box is
      // never opened on an old plan.
      _refresh();
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

  /// Asks first, like the side drawer does: it is one tap away from the boxes.
  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your session will end on this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
    showToast(context, 'Press back again to exit');
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
                final name = user?.displayName.trim() ?? '';
                final first = name.isEmpty ? '' : name.split(' ').first;
                final hasPlan = user?.hasPlan ?? false;
                final plan = user?.planName?.trim() ?? '';
                final greeting = hubGreeting(DateTime.now().hour);
                return RefreshIndicator(
                  color: brand,
                  onRefresh: _refresh,
                  child: ContentWidth(
                    maxWidth: 560,
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
                              Semantics(
                                header: true,
                                child: Text(
                                  first.isEmpty
                                      ? 'Welcome to Eydia'
                                      : '$greeting, $first',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
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
                              if (hasPlan && plan.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _PlanPill(plan),
                              ],
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
                        const SizedBox(height: 6),
                        FadeIn(
                          delay: 320,
                          child: Row(
                            children: [
                              Expanded(
                                child: _FooterTile(
                                  Icons.person_rounded,
                                  'My profile',
                                  () => _openPage(
                                    'My Profile',
                                    ProfileScreen(
                                      onSignedOut: widget.onSignedOut,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FooterTile(
                                  Icons.workspace_premium_rounded,
                                  'Plan and credits',
                                  () => _openPage(
                                    'Plan and credits',
                                    const BillingScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FooterTile(
                                  Icons.logout_rounded,
                                  'Sign out',
                                  _signOut,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

/// The plan name on the dark background, so it is clear what the boxes
/// below are unlocked by.
class _PlanPill extends StatelessWidget {
  const _PlanPill(this.plan);

  final String plan;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your plan: $plan',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: royalGold.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 14,
              color: royalGold,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                plan,
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
    final highlights = hubHighlights[product] ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        button: true,
        label: unlocked
            ? 'Open ${product.title}. ${product.subtitle}'
            : '${product.title}, ${hasPlan ? 'not in your plan' : 'plan needed'}',
        excludeSemantics: true,
        // The white fill and the shadow sit on the outer box; the ripple is
        // drawn on a transparent Material above it. (A shadow behind a box
        // with no fill shows through it as grey.)
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              height: 1.2,
                              color: unlocked ? ink : inkSoft,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              height: 1.35,
                              color: muted,
                            ),
                          ),
                          if (highlights.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final h in highlights)
                                  InfoChip(h, color: unlocked ? brand : muted),
                              ],
                            ),
                          ],
                          if (!unlocked) ...[
                            const SizedBox(height: 10),
                            StatusBadge(
                              hasPlan ? 'Not in your plan' : 'Plan needed',
                              warn,
                              icon: Icons.lock_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Icon(
                        unlocked
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.lock_outline_rounded,
                        size: unlocked ? 16 : 20,
                        color: unlocked ? brand : muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the three small actions under the boxes: an icon over a short label.
class _FooterTile extends StatelessWidget {
  const _FooterTile(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: Colors.white),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.2,
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
