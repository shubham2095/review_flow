import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/admin_models.dart';
import 'package:review_flow/screens/admin_company_filters.dart';

AdminCompany _c(
  String name, {
  String? plan,
  String status = 'active',
  String owner = 'Owner',
  String email = 'o@example.com',
  int agents = 0,
  int? limit,
  DateTime? trial,
}) => AdminCompany(
  id: name,
  name: name,
  status: status,
  usersCount: 1,
  ownerName: owner,
  ownerEmail: email,
  agentsUsed: agents,
  agentsLimit: limit,
  planName: plan,
  trialEndsAt: trial,
);

AdminPayment _p(
  String number,
  String company, {
  String status = 'paid',
  String? plan,
  String? customer,
  String? gateway,
}) => AdminPayment(
  number: number,
  company: company,
  status: status,
  total: '₹1,000.00',
  plan: plan,
  customer: customer,
  gateway: gateway,
);

void main() {
  final companies = [
    _c('Pizi India', plan: 'Pro', owner: 'Asha', email: 'asha@pizi.in'),
    _c('Heltog', plan: 'Starter', status: 'suspended', owner: 'Jay'),
    _c('HomeSaaz', owner: 'Karishma', email: 'k@homesaaz.com'),
    _c('Eydia Labs', plan: 'Pro', owner: 'Shubham'),
  ];

  List<String> names(AdminCompanyFilter f) =>
      filterCompanies(companies, f).map((c) => c.name).toList();

  group('filterCompanies', () {
    test('no filter keeps everything in order', () {
      expect(names(const AdminCompanyFilter()), [
        'Pizi India',
        'Heltog',
        'HomeSaaz',
        'Eydia Labs',
      ]);
    });

    test('status', () {
      expect(
        names(const AdminCompanyFilter(status: AdminCompanyStatus.active)),
        ['Pizi India', 'HomeSaaz', 'Eydia Labs'],
      );
      expect(
        names(const AdminCompanyFilter(status: AdminCompanyStatus.suspended)),
        ['Heltog'],
      );
      expect(
        names(const AdminCompanyFilter(status: AdminCompanyStatus.noPlan)),
        ['HomeSaaz'],
      );
    });

    test('plan', () {
      expect(names(const AdminCompanyFilter(plan: 'Pro')), [
        'Pizi India',
        'Eydia Labs',
      ]);
      expect(names(const AdminCompanyFilter(plan: 'Nope')), isEmpty);
    });

    test('search matches name, owner name and owner email, any case', () {
      expect(names(const AdminCompanyFilter(query: 'HELTOG')), ['Heltog']);
      expect(names(const AdminCompanyFilter(query: 'karish')), ['HomeSaaz']);
      expect(names(const AdminCompanyFilter(query: '@pizi.in')), [
        'Pizi India',
      ]);
      expect(names(const AdminCompanyFilter(query: '  ')), hasLength(4));
    });

    test('filters combine', () {
      expect(
        names(
          const AdminCompanyFilter(
            status: AdminCompanyStatus.active,
            plan: 'Pro',
            query: 'eydia',
          ),
        ),
        ['Eydia Labs'],
      );
      expect(
        names(
          const AdminCompanyFilter(
            status: AdminCompanyStatus.suspended,
            plan: 'Pro',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('labels', () {
    final now = DateTime(2026, 11, 18);

    test('trialLabel says until or ended, or nothing', () {
      expect(
        trialLabel(_c('A', trial: DateTime(2026, 11, 25)), now),
        startsWith('Trial until'),
      );
      expect(
        trialLabel(_c('A', trial: DateTime(2026, 11, 1)), now),
        startsWith('Trial ended'),
      );
      expect(trialLabel(_c('A'), now), isNull);
    });

    test('agentsLabel with and without a limit', () {
      expect(agentsLabel(_c('A', agents: 3, limit: 5)), '3/5 agents');
      expect(agentsLabel(_c('A', agents: 3)), '3 agents');
      expect(agentsLabel(_c('A', agents: 1)), '1 agent');
      expect(agentsLabel(_c('A', agents: 3, limit: -1)), '3 agents');
    });
  });

  group('payments', () {
    final payments = [
      _p('INV-1', 'Pizi India', plan: 'Pro', gateway: 'razorpay'),
      _p('INV-2', 'Heltog', status: 'failed', customer: 'Jay'),
      _p('INV-3', 'Pizi India', status: 'paid', plan: 'Starter'),
      _p('INV-4', 'HomeSaaz', status: 'pending'),
    ];

    List<String> numbers({String q = '', String? s}) => filterPayments(
      payments,
      query: q,
      status: s,
    ).map((p) => p.number).toList();

    test('no filter keeps all', () {
      expect(numbers(), ['INV-1', 'INV-2', 'INV-3', 'INV-4']);
    });

    test('search covers number, company, customer, plan and gateway', () {
      expect(numbers(q: 'inv-2'), ['INV-2']);
      expect(numbers(q: 'pizi'), ['INV-1', 'INV-3']);
      expect(numbers(q: 'jay'), ['INV-2']);
      expect(numbers(q: 'starter'), ['INV-3']);
      expect(numbers(q: 'razor'), ['INV-1']);
    });

    test('status and search combine', () {
      expect(numbers(s: 'paid'), ['INV-1', 'INV-3']);
      expect(numbers(s: 'paid', q: 'starter'), ['INV-3']);
      expect(numbers(s: 'failed', q: 'pizi'), isEmpty);
    });

    test('paymentStatuses lists each once, most common first', () {
      expect(paymentStatuses(payments), ['paid', 'failed', 'pending']);
      expect(paymentStatuses(const []), isEmpty);
    });
  });
}
