import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/admin_models.dart';
import 'package:review_flow/screens/admin_dashboard_screen.dart';

AdminCompany _company(
  String name, {
  String? plan,
  String status = 'active',
  int users = 1,
  DateTime? created,
}) => AdminCompany(
  id: name,
  name: name,
  status: status,
  usersCount: users,
  ownerName: 'Owner',
  ownerEmail: 'o@example.com',
  agentsUsed: 0,
  planName: plan,
  createdAt: created,
);

final _plans = [
  AdminPlanOption('p1', 'Starter'),
  AdminPlanOption('p2', 'Pro'),
  AdminPlanOption('p3', 'Unused'),
];

void main() {
  group('adminOverview', () {
    test('counts companies, status, users and plans', () {
      final o = adminOverview([
        _company('A', plan: 'Pro', users: 3),
        _company('B', plan: 'Pro', users: 2, status: 'suspended'),
        _company('C', plan: 'Starter'),
        _company('D'),
      ], _plans);
      expect(o.total, 4);
      expect(o.active, 3);
      expect(o.suspended, 1);
      expect(o.users, 7);
      expect(o.noPlan, 1);
      expect(o.planCount, 3);
      expect(o.otherPlan, 0);
    });

    test('plans are listed busiest first, empty ones last, all shown', () {
      final o = adminOverview([
        _company('A', plan: 'Pro'),
        _company('B', plan: 'Pro'),
        _company('C', plan: 'Starter'),
      ], _plans);
      expect(o.byPlan.map((e) => e.plan).toList(), [
        'Pro',
        'Starter',
        'Unused',
      ]);
      expect(o.byPlan.map((e) => e.companies).toList(), [2, 1, 0]);
    });

    test('equal counts keep the server order', () {
      final o = adminOverview([
        _company('A', plan: 'Pro'),
        _company('B', plan: 'Starter'),
      ], _plans);
      expect(o.byPlan.first.plan, 'Starter'); // Starter came first in _plans
    });

    test('a company on a plan that is no longer offered is counted apart', () {
      final o = adminOverview([
        _company('A', plan: 'Legacy'),
        _company('B', plan: 'Pro'),
      ], _plans);
      expect(o.otherPlan, 1);
      expect(o.noPlan, 0);
      // Every company is in exactly one bucket.
      final listed = o.byPlan.fold<int>(0, (s, e) => s + e.companies);
      expect(listed + o.otherPlan + o.noPlan, o.total);
    });

    test('no companies gives zeros', () {
      final o = adminOverview(const [], _plans);
      expect(o.total, 0);
      expect(o.users, 0);
      expect(o.byPlan.every((e) => e.companies == 0), isTrue);
    });
  });

  group('newestCompanies', () {
    test('newest first, undated last, limited', () {
      final list = newestCompanies([
        _company('old', created: DateTime(2026, 1, 1)),
        _company('undated'),
        _company('new', created: DateTime(2026, 11, 1)),
        _company('mid', created: DateTime(2026, 6, 1)),
      ], limit: 3);
      expect(list.map((c) => c.name).toList(), ['new', 'mid', 'old']);
    });

    test('fewer companies than the limit returns them all', () {
      expect(newestCompanies([_company('A')]), hasLength(1));
      expect(newestCompanies(const []), isEmpty);
    });
  });
}
