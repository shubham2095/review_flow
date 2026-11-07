import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/account_models.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../services/platform_rules.dart';
import '../services/session.dart';
import '../services/web_handoff.dart';
import '../theme/brand.dart';
import '../widgets/count_up.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/text_scale.dart';

/// Your plan, AI credits, available plans and payment history. Nothing is bought
/// in the app: every purchase button opens the web app, already signed in.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with WidgetsBindingObserver {
  SubscriptionInfo? _subscription;
  CreditsInfo? _credits;
  List<PlanInfo> _plans = [];
  List<CreditPackInfo> _packs = [];
  List<BillingInvoice> _invoices = [];
  bool _loading = true;
  bool _opening = false;
  bool _wentToWeb = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the web (after paying) shows the new plan and credits
  /// without anyone having to pull down.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToWeb) {
      _wentToWeb = false;
      _load();
      Session.refresh().then((_) {}, onError: (_) {});
    }
  }

  /// One failing section (for example a role without billing access) should
  /// not blank the rest of the page.
  Future<T?> _safe<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      _error ??= friendlyException(e).message;
      return null;
    }
  }

  Future<void> _load() async {
    _error = null;
    final results = await Future.wait([
      _safe(AccountService.subscription),
      _safe(AccountService.credits),
      _safe(AccountService.plans),
      _safe(AccountService.creditPacks),
      _safe(AccountService.invoices),
    ]);
    if (!mounted) return;
    setState(() {
      _subscription = results[0] as SubscriptionInfo?;
      _credits = results[1] as CreditsInfo?;
      _plans = (results[2] as List<PlanInfo>?) ?? [];
      _packs = (results[3] as List<CreditPackInfo>?) ?? [];
      _invoices = (results[4] as List<BillingInvoice>?) ?? [];
      _loading = false;
    });
  }

  Future<void> _web(String next) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openInWeb(next: next);
      _wentToWeb = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyException(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = _subscription;
    final credits = _credits;
    final hasData = sub != null || credits != null || _plans.isNotEmpty;

    return Scaffold(
      backgroundColor: surface,
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading
            ? const SkeletonList(count: 3, itemHeight: 120, headerHeight: 170)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (!hasData && _error != null)
                    StateView.error(
                      title: 'Could not load billing',
                      text: _error!,
                      onRetry: () {
                        setState(() => _loading = true);
                        _load();
                      },
                    )
                  else ...[
                    // Some sections loaded, some did not: say so instead of
                    // quietly showing a shorter page.
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: warn.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: warn.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: warn),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Some details could not load. Pull down to try again.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    FadeIn(
                      child: _PlanCard(
                        subscription: sub,
                        busy: _opening,
                        onManage: purchaseLinksAllowed ? () => _web("/billing") : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (credits != null)
                      FadeIn(
                        delay: 80,
                        child: _CreditsCard(
                          credits: credits,
                          busy: _opening,
                          onBuy: purchaseLinksAllowed
                              ? () => _web('/buy-credits')
                              : null,
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Plans, credit packs and anything that sends people off to buy
                    // are not shown on iOS (platform_rules.dart).
                    if (purchaseLinksAllowed) const _WebNote(),
                    if (purchaseLinksAllowed && _plans.isNotEmpty) ...[
                      const _Title('Plans'),
                      for (var i = 0; i < _plans.length; i++)
                        FadeIn(
                          delay: 120 + i * 70,
                          child: _PlanTile(
                            plan: _plans[i],
                            current: sub != null &&
                                sub.planName.toLowerCase() ==
                                    _plans[i].name.toLowerCase(),
                            busy: _opening,
                            onChoose: () => _web('/plans'),
                          ),
                        ),
                    ],
                    if (purchaseLinksAllowed && _packs.isNotEmpty) ...[
                      const _Title('Credit packs'),
                      SizedBox(
                        height: textScaled(context, 108),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _packs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (_, i) => _PackTile(
                            pack: _packs[i],
                            onTap: () => _web('/buy-credits'),
                          ),
                        ),
                      ),
                    ],
                    if (_invoices.isNotEmpty) ...[
                      const _Title('Payment history'),
                      for (final inv in _invoices) _InvoiceRow(invoice: inv),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
    );
  }
}

class _WebNote extends StatelessWidget {
  const _WebNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Payments are completed securely on the web. You stay signed in.',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'active':
    case 'trialing':
    case 'paid':
      return good;
    case 'past_due':
    case 'expired':
    case 'cancelled':
    case 'failed':
      return bad;
    default:
      return muted;
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.subscription,
    required this.busy,
    required this.onManage,
  });

  final SubscriptionInfo? subscription;
  final bool busy;
  /// Null on iOS: no way to buy from there (platform_rules.dart).
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    String detail = 'Choose a plan to unlock your workspace.';
    if (sub != null) {
      if (sub.status == 'trialing' && sub.trialEndsAt != null) {
        detail = 'Trial ends ${fmtDate(sub.trialEndsAt!)}';
      } else if (sub.currentPeriodEnd != null) {
        detail = sub.status == 'active'
            ? 'Renews ${fmtDate(sub.currentPeriodEnd!)}'
            : 'Ended ${fmtDate(sub.currentPeriodEnd!)}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brand, brandDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT PLAN',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  sub == null || sub.planName.isEmpty ? 'No active plan' : sub.planName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (sub != null && sub.status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    sub.status.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
          ),
          // A plan that has run out should say what to do, not just a date.
          if (sub != null &&
              const {'past_due', 'expired', 'cancelled'}.contains(sub.status)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: royalGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // On iOS the wording does not point anywhere to pay.
                      sub.status == 'past_due'
                          ? (purchaseLinksAllowed
                              ? 'Your last payment did not go through. Update it on the web to keep your workspace active.'
                              : 'Your last payment did not go through.')
                          : (purchaseLinksAllowed
                              ? 'Your plan is no longer active. Renew on the web to keep using Eydia.'
                              : 'Your plan is no longer active.'),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onManage != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : onManage,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: brand,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(sub == null ? 'Choose a plan on web' : 'Manage plan on web'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({
    required this.credits,
    required this.busy,
    required this.onBuy,
  });

  final CreditsInfo credits;
  final bool busy;
  /// Null on iOS: no way to buy from there (platform_rules.dart).
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final allowance = credits.allowance <= 0 ? 1 : credits.allowance;
    final ratio = (credits.balance / allowance).clamp(0.0, 1.0);
    final recent = credits.ledger.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: star),
              const SizedBox(width: 8),
              Text(
                'AI credits',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const Spacer(),
              CountUp(
                value: credits.balance,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: ratio < 0.2 ? bad : brand,
                backgroundColor: const Color(0xFFEEF1F7),
              ),
            ),
          ),
          if (ratio < 0.2) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 15, color: bad),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    credits.balance <= 0
                        ? (purchaseLinksAllowed
                            ? 'You are out of credits. AI drafts and posts will not work until you add more.'
                            : 'You are out of credits, so AI drafts and posts will not work.')
                        : 'Credits are running low.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: bad,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            credits.resetAt == null
                ? '${credits.allowance} credits per period'
                : '${credits.allowance} credits per period, resets ${fmtDate(credits.resetAt!)}',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
          ),
          if (onBuy != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : onBuy,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Buy more credits on web'),
            ),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Recent activity',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            for (final e in recent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                      ),
                    ),
                    Text(
                      e.delta > 0 ? '+${e.delta}' : '${e.delta}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: e.delta > 0 ? good : ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// "review_replies" -> "Review replies".
String _featureLabel(String key) {
  final text = key.replaceAll('_', ' ').trim();
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.current,
    required this.busy,
    required this.onChoose,
  });

  final PlanInfo plan;
  final bool current;
  final bool busy;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration().copyWith(
        border: Border.all(
          color: current ? brand.withValues(alpha: 0.5) : const Color(0xFFEEF1F7),
          width: current ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: ink,
                  ),
                ),
              ),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: good.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Current',
                    style: GoogleFonts.plusJakartaSans(
                      color: good,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            plan.billingPeriod.isEmpty
                ? plan.priceDisplay
                : '${plan.priceDisplay} / ${plan.billingPeriod}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: brand,
            ),
          ),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              plan.description,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted, height: 1.4),
            ),
          ],
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in plan.features.take(8))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _featureLabel(f),
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: ink),
                    ),
                  ),
              ],
            ),
          ],
          if (!current) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : onChoose,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Choose ${plan.name} on web'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.pack, required this.onTap});

  final CreditPackInfo pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              pack.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: muted,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${pack.credits} credits',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ink,
                ),
              ),
            ),
            Text(
              '₹${pack.price.toStringAsFixed(pack.price % 1 == 0 ? 0 : 2)}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final BillingInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(invoice.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  invoice.issuedAt == null ? '' : fmtDate(invoice.issuedAt!),
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                invoice.total,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                invoice.status.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
