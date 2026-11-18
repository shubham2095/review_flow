import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/admin_models.dart';
import 'package:review_flow/screens/admin_plans_screen.dart';

void main() {
  group('planFormProblem', () {
    test('a name is required', () {
      expect(
        planFormProblem(name: ' ', priceText: '', gstText: ''),
        contains('name'),
      );
    });

    test('price and GST may be empty', () {
      expect(planFormProblem(name: 'Pro', priceText: '', gstText: ''), isNull);
    });

    test('price must be a number, 0 or more', () {
      expect(
        planFormProblem(name: 'Pro', priceText: 'x', gstText: ''),
        contains('price'),
      );
      expect(
        planFormProblem(name: 'Pro', priceText: '-1', gstText: ''),
        contains('price'),
      );
      expect(
        planFormProblem(name: 'Pro', priceText: '1999.50', gstText: ''),
        isNull,
      );
    });

    test('GST is a whole number from 0 to 100', () {
      for (final bad in ['x', '-1', '101', '18.5']) {
        expect(
          planFormProblem(name: 'Pro', priceText: '10', gstText: bad),
          contains('GST'),
          reason: bad,
        );
      }
      for (final good in ['0', '5', '18', '100']) {
        expect(
          planFormProblem(name: 'Pro', priceText: '10', gstText: good),
          isNull,
          reason: good,
        );
      }
    });
  });

  group('AdminPlan GST', () {
    Map<String, dynamic> json({Object? own, Object? effective = 18}) => {
      'id': 'p1',
      'name': 'Pro',
      'gst_rate': effective,
      'gst_rate_own': own,
    };

    test('a plan with its own GST keeps it apart from the platform rate', () {
      final p = AdminPlan.fromJson(json(own: 12, effective: 12));
      expect(p.gstRate, 12);
      expect(p.gstRateOwn, 12);
    });

    test('a plan on the platform rate has no own GST', () {
      final p = AdminPlan.fromJson(json());
      expect(p.gstRate, 18);
      expect(p.gstRateOwn, isNull);
    });

    test('an own GST of 0 is a real value, not "none"', () {
      expect(AdminPlan.fromJson(json(own: 0, effective: 0)).gstRateOwn, 0);
    });
  });

  test('every plan currency is a three-letter code', () {
    expect(planCurrencies.every((c) => c.length == 3), isTrue);
    expect(planCurrencies, contains('INR'));
  });
}
