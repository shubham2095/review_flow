import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/skeleton.dart';
import 'admin_company_filters.dart';

/// The numbers on the admin dashboard, worked out from the companies list
/// (the same way the web dashboard does it).
class AdminOverview {
  const AdminOverview({
    required this.total,
    required this.active,
    required this.suspended,
    required this.users,
    required this.noPlan,
    required this.byPlan,
    required this.otherPlan,
    required this.planCount,
  });

  final int total;
  final int active;
  final int suspended;

  /// Every user in every company.
  final int users;

  /// Companies with no plan at all.
  final int noPlan;

  /// Companies per active plan, the busiest first (plans nobody has are kept,
  /// at the end, so every plan shows).
  final List<({String plan, int companies})> byPlan;

  /// Companies on a plan that is not in the active list (an old plan).
  final int otherPlan;

  /// How many plans can be given out now.
  final int planCount;
}

/// Counts companies by status and plan. [plans] are the plans that can be
/// given out (what the server sends with the companies).
AdminOverview adminOverview(
  List<AdminCompany> companies,
  List<AdminPlanOption> plans,
) {
  final names = {for (final p in plans) p.name};
  final byPlan = [
    for (final p in plans)
      (
        plan: p.name,
        companies: companies.where((c) => c.planName == p.name).length,
      ),
  ];
  // Busiest first; the sort is stable for equal counts, so plans keep the
  // server's order among themselves.
  final indexed = [for (var i = 0; i < byPlan.length; i++) (i, byPlan[i])];
  indexed.sort((a, b) {
    final c = b.$2.companies.compareTo(a.$2.companies);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return AdminOverview(
    total: companies.length,
    active: companies.where((c) => !c.suspended).length,
    suspended: companies.where((c) => c.suspended).length,
    users: companies.fold<int>(0, (s, c) => s + c.usersCount),
    noPlan: companies.where((c) => c.planName == null).length,
    byPlan: [for (final e in indexed) e.$2],
    otherPlan: companies
        .where((c) => c.planName != null && !names.contains(c.planName))
        .length,
    planCount: plans.length,
  );
}

/// The newest companies first, at most [limit].
List<AdminCompany> newestCompanies(
  List<AdminCompany> companies, {
  int limit = 5,
}) {
  final list = [...companies];
  list.sort((a, b) {
    final x = a.createdAt, y = b.createdAt;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return y.compareTo(x);
  });
  return list.take(limit).toList();
}

/// The super admin's first screen: companies, plans, users and revenue at a
/// glance. A tile opens the section it is about.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.onOpenCompanies,
    required this.onOpenPlans,
    required this.onOpenPayments,
  });

  /// Opens the Companies list, narrowed to what was tapped.
  final void Function(AdminCompanyFilter filter) onOpenCompanies;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenPayments;

  @override
  State<AdminDashboardScreen> createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<AdminCompany> _companies = [];
  List<AdminPlanOption> _plans = [];
  AdminPaymentsData? _payments;
  bool _loading = true;
  String? _error;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Reloads quietly when what is on screen is over a minute old (the admin
  /// may have changed a plan or a company in another section).
  void refreshIfStale() {
    final at = _loadedAt;
    if (at == null ||
        DateTime.now().difference(at) > const Duration(minutes: 1)) {
      reload();
    }
  }

  Future<void> reload() async {
    try {
      final data = await AdminService.companies();
      // Revenue only decorates the dashboard: do without it if it fails.
      AdminPaymentsData? payments = _payments;
      try {
        payments = await AdminService.payments();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _companies = data.companies;
        _plans = data.plans;
        _payments = payments;
        _error = null;
        _loadedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: ink,
        ),
      ),
    ),
  );

  Widget _planRow(String plan, int count, int total, {VoidCallback? onTap}) {
    final share = total == 0 ? 0.0 : count / total;
    final label = '$plan, $count ${count == 1 ? 'company' : 'companies'}';
    return Semantics(
      button: onTap != null,
      container: true,
      excludeSemantics: true,
      label: label,
      hint: onTap == null ? null : 'Opens these companies',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: ink,
                        ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: ink,
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: muted,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 8,
                    color: royalIndigo,
                    backgroundColor: track,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final o = adminOverview(_companies, _plans);
    final p = _payments;
    final newest = newestCompanies(_companies);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        FadeIn(
          child: adminTileGrid(
            children: [
              AdminStatTile(
                label: 'Total companies',
                value: '${o.total}',
                icon: Icons.business_rounded,
                color: brand,
                onTap: () => widget.onOpenCompanies(const AdminCompanyFilter()),
              ),
              AdminStatTile(
                label: 'Active companies',
                value: '${o.active}',
                icon: Icons.check_circle_rounded,
                color: good,
                note: o.suspended > 0 ? '${o.suspended} suspended' : null,
                onTap: () => widget.onOpenCompanies(
                  const AdminCompanyFilter(status: AdminCompanyStatus.active),
                ),
              ),
              AdminStatTile(
                label: 'Plans',
                value: '${o.planCount}',
                icon: Icons.workspace_premium_rounded,
                color: royalViolet,
                onTap: widget.onOpenPlans,
              ),
              AdminStatTile(
                label: 'Total users',
                value: '${o.users}',
                icon: Icons.groups_rounded,
                color: warn,
                onTap: () => widget.onOpenCompanies(const AdminCompanyFilter()),
              ),
              AdminStatTile(
                label: 'Revenue',
                value: p == null || p.revenue.isEmpty ? '—' : p.revenue,
                icon: Icons.payments_rounded,
                color: royalIndigo,
                note: p == null ? null : '${p.paid} paid of ${p.count}',
                onTap: widget.onOpenPayments,
              ),
            ],
          ),
        ),
        if (o.noPlan > 0)
          FadeIn(
            delay: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                button: true,
                excludeSemantics: true,
                label:
                    '${o.noPlan} ${o.noPlan == 1 ? 'customer has' : 'customers have'} no plan. Open companies',
                child: Material(
                  color: warn.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => widget.onOpenCompanies(
                      const AdminCompanyFilter(
                        status: AdminCompanyStatus.noPlan,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: warn),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${o.noPlan} ${o.noPlan == 1 ? 'customer has' : 'customers have'} '
                              'no plan yet',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        _heading('Customers by plan'),
        FadeIn(
          delay: 100,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            decoration: cardDecoration(),
            child: o.total == 0
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No companies yet.',
                      style: GoogleFonts.plusJakartaSans(color: muted),
                    ),
                  )
                : Column(
                    children: [
                      for (final e in o.byPlan)
                        _planRow(
                          e.plan,
                          e.companies,
                          o.total,
                          onTap: () => widget.onOpenCompanies(
                            AdminCompanyFilter(plan: e.plan),
                          ),
                        ),
                      if (o.otherPlan > 0)
                        _planRow('Other plans', o.otherPlan, o.total),
                      _planRow(
                        'No plan',
                        o.noPlan,
                        o.total,
                        onTap: () => widget.onOpenCompanies(
                          const AdminCompanyFilter(
                            status: AdminCompanyStatus.noPlan,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        _heading('Newest companies'),
        if (newest.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Companies you add will show here.',
              style: GoogleFonts.plusJakartaSans(color: muted),
            ),
          ),
        for (var i = 0; i < newest.length; i++)
          FadeIn(
            delay: 140 + i * 40,
            child: Semantics(
              button: true,
              excludeSemantics: true,
              label:
                  '${newest[i].name}, ${newest[i].planName ?? 'no plan'}'
                  '${newest[i].createdAt == null ? '' : ', added ${fmtDate(newest[i].createdAt!)}'}',
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: cardDecoration(),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => widget.onOpenCompanies(
                      AdminCompanyFilter(query: newest[i].name),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  newest[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                                if (newest[i].createdAt != null)
                                  Text(
                                    'Added ${fmtDate(newest[i].createdAt!)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AdminBadge(
                            newest[i].planName ?? 'No plan',
                            newest[i].planName == null ? warn : brand,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: RefreshIndicator(
        color: brand,
        onRefresh: reload,
        child: _loading
            ? const SkeletonList(count: 3, itemHeight: 110, headerHeight: 130)
            : _error != null && _companies.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AdminMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load the dashboard',
                    text: _error!,
                    onRetry: () {
                      setState(() => _loading = true);
                      reload();
                    },
                  ),
                ],
              )
            : _content(),
      ),
    );
  }
}

/// One number on the dashboard: an icon, a big value, a label and an optional
/// note. It is as tall as its content, so it never overflows at large text
/// sizes.
class AdminStatTile extends StatelessWidget {
  const AdminStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.note,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      container: true,
      excludeSemantics: true,
      label: '$label $value${note == null ? '' : ', $note'}',
      child: Container(
        decoration: cardDecoration(),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: ink,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                  if (note != null)
                    Text(
                      note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: muted,
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

/// The tiles two to a row. Each row is as tall as its tallest tile, so bigger
/// text sizes make the tiles taller instead of overflowing.
Widget adminTileGrid({required List<Widget> children}) {
  final rows = <Widget>[];
  for (var i = 0; i < children.length; i += 2) {
    if (i > 0) rows.add(const SizedBox(height: 12));
    rows.add(
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 12),
            Expanded(
              child: i + 1 < children.length
                  ? children[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
  return Column(children: rows);
}
