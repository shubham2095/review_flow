import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/account_models.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../services/web_handoff.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';

/// Your plan, AI credits, available plans and payment history. Nothing is bought
/// in the app: every purchase button opens the web app, already signed in.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  SubscriptionInfo? _subscription;
  CreditsInfo? _credits;
  List<PlanInfo> _plans = [];
  List<CreditPackInfo> _packs = [];
  List<BillingInvoice> _invoices = [];
  bool _loading = true;
  bool _opening = false;
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
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (!hasData && _error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 44, color: muted),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: () {
                              setState(() => _loading = true);
                              _load();
                            },
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    FadeIn(
                      child: _PlanCard(
                        subscription: sub,
                        busy: _opening,
                        onManage: () => _web('/billing'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (credits != null)
                      FadeIn(
                        delay: 80,
                        child: _CreditsCard(
                          credits: credits,
                          busy: _opening,
                          onBuy: () => _web('/buy-credits'),
                        ),
                      ),
                    const SizedBox(height: 6),
                    const _WebNote(),
                    if (_plans.isNotEmpty) ...[
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
                    if (_packs.isNotEmpty) ...[
                      const _Title('Credit packs'),
                      SizedBox(
                        height: 108,
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
  final VoidCallback onManage;

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
  final VoidCallback onBuy;

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
              Text(
                '${credits.balance}',
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
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: ratio < 0.2 ? bad : brand,
              backgroundColor: const Color(0xFFEEF1F7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            credits.resetAt == null
                ? '${credits.allowance} credits per period'
                : '${credits.allowance} credits per period, resets ${fmtDate(credits.resetAt!)}',
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : onBuy,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Buy more credits on web'),
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
      decoration: cardDecoration(),
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
                      f.replaceAll('_', ' '),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
