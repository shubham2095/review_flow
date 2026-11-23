import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/account_models.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/count_up.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';

/// Your plan, AI credits and payment history: details only. The app never
/// sells or renews anything, so there are no buy buttons or links here.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  SubscriptionInfo? _subscription;
  CreditsInfo? _credits;
  List<BillingInvoice> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      _safe(AccountService.invoices),
    ]);
    if (!mounted) return;
    setState(() {
      _subscription = results[0] as SubscriptionInfo?;
      _credits = results[1] as CreditsInfo?;
      _invoices = (results[2] as List<BillingInvoice>?) ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = _subscription;
    final credits = _credits;
    final hasData = sub != null || credits != null;

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
                          border: Border.all(
                            color: warn.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: warn,
                            ),
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
                    FadeIn(child: _PlanCard(subscription: sub)),
                    const SizedBox(height: 14),
                    if (credits != null)
                      FadeIn(delay: 80, child: _CreditsCard(credits: credits)),
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
  const _PlanCard({required this.subscription});

  final SubscriptionInfo? subscription;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    String detail = 'This account does not have an active plan yet.';
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
                  sub == null || sub.planName.isEmpty
                      ? 'No active plan'
                      : sub.planName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (sub != null && sub.status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
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
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          // A plan that has run out should say what to do, not just a date.
          if (sub != null &&
              const {
                'past_due',
                'expired',
                'cancelled',
              }.contains(sub.status)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: royalGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sub.status == 'past_due'
                          ? 'Your last payment did not go through.'
                          : 'Your plan is no longer active.',
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
        ],
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({required this.credits});

  final CreditsInfo credits;

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
                        ? 'You are out of credits, so AI drafts and posts will not work.'
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: muted,
                        ),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: muted,
                  ),
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
