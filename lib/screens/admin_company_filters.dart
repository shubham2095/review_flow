import '../models/admin_models.dart';
import '../widgets/date_format.dart';

/// Which companies the list shows by status.
enum AdminCompanyStatus {
  all('All'),
  active('Active'),
  suspended('Suspended'),
  noPlan('No plan');

  const AdminCompanyStatus(this.label);

  final String label;
}

/// What the Companies list is narrowed to. The dashboard sends one of these
/// when a tile or a plan row is tapped.
class AdminCompanyFilter {
  const AdminCompanyFilter({
    this.status = AdminCompanyStatus.all,
    this.plan,
    this.query = '',
  });

  final AdminCompanyStatus status;

  /// A plan's name, or null for every plan.
  final String? plan;

  /// Matches the company name, the owner's name or the owner's email.
  final String query;
}

/// The companies that pass [filter], in their original order.
List<AdminCompany> filterCompanies(
  List<AdminCompany> companies,
  AdminCompanyFilter filter,
) {
  final q = filter.query.trim().toLowerCase();
  return companies.where((c) {
    switch (filter.status) {
      case AdminCompanyStatus.all:
        break;
      case AdminCompanyStatus.active:
        if (c.suspended) return false;
      case AdminCompanyStatus.suspended:
        if (!c.suspended) return false;
      case AdminCompanyStatus.noPlan:
        if (c.planName != null) return false;
    }
    if (filter.plan != null && c.planName != filter.plan) return false;
    if (q.isEmpty) return true;
    return c.name.toLowerCase().contains(q) ||
        c.ownerName.toLowerCase().contains(q) ||
        c.ownerEmail.toLowerCase().contains(q);
  }).toList();
}

/// "Trial until 20 Nov 2026", "Trial ended 3 Nov 2026", or null when the
/// company has no trial date.
String? trialLabel(AdminCompany c, [DateTime? now]) {
  final end = c.trialEndsAt;
  if (end == null) return null;
  final at = now ?? DateTime.now();
  return end.isAfter(at)
      ? 'Trial until ${fmtDate(end)}'
      : 'Trial ended ${fmtDate(end)}';
}

/// "3/5 agents" with a limit, "3 agents" without one (or an unlimited plan).
String agentsLabel(AdminCompany c) =>
    c.agentsLimit == null || c.agentsLimit! < 0
    ? '${c.agentsUsed} ${c.agentsUsed == 1 ? 'agent' : 'agents'}'
    : '${c.agentsUsed}/${c.agentsLimit} agents';

/// The payments that match [query] (number, company, customer, plan or
/// gateway) and [status] (null for every status).
List<AdminPayment> filterPayments(
  List<AdminPayment> payments, {
  String query = '',
  String? status,
}) {
  final q = query.trim().toLowerCase();
  return payments.where((p) {
    if (status != null && p.status != status) return false;
    if (q.isEmpty) return true;
    return [
      p.number,
      p.company,
      p.customer ?? '',
      p.plan ?? '',
      p.gateway ?? '',
    ].any((s) => s.toLowerCase().contains(q));
  }).toList();
}

/// The distinct statuses in [payments], most common first.
List<String> paymentStatuses(List<AdminPayment> payments) {
  final counts = <String, int>{};
  for (final p in payments) {
    if (p.status.isEmpty) continue;
    counts[p.status] = (counts[p.status] ?? 0) + 1;
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return keys;
}
