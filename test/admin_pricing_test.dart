import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/admin_pricing_models.dart';
import 'package:review_flow/screens/admin_pricing_screen.dart';
import 'package:review_flow/theme/brand.dart';

AdminCoupon _coupon({
  String type = 'percent',
  double value = 20,
  double? maxDiscount,
  double? minAmount,
  int? maxUses,
  int used = 0,
  bool active = true,
  bool live = true,
  DateTime? starts,
  DateTime? expires,
}) => AdminCoupon(
  id: 'c1',
  code: 'DIWALI20',
  type: type,
  value: value,
  maxDiscount: maxDiscount,
  minAmount: minAmount,
  maxUses: maxUses,
  usedCount: used,
  isActive: active,
  live: live,
  startsAt: starts,
  expiresAt: expires,
);

String? _problem({
  String code = 'DIWALI20',
  String type = 'percent',
  String value = '20',
  String max = '',
  String min = '',
  String uses = '',
  DateTime? starts,
  DateTime? ends,
}) => couponProblem(
  code: code,
  type: type,
  valueText: value,
  maxDiscountText: max,
  minAmountText: min,
  maxUsesText: uses,
  startsAt: starts,
  expiresAt: ends,
);

void main() {
  group('couponProblem', () {
    test('a good coupon passes, and the code may be typed in lower case', () {
      expect(_problem(), isNull);
      expect(_problem(code: ' diwali-20_a '), isNull);
    });

    test('the code must be filled, short and plain', () {
      expect(_problem(code: ' '), contains('code'));
      expect(_problem(code: 'A' * 41), contains('40'));
      expect(_problem(code: 'SAVE 20'), contains('letters'));
      expect(_problem(code: 'SAVE%'), contains('letters'));
    });

    test('the value must be a number, and a percent at most 100', () {
      expect(_problem(value: ''), contains('value'));
      expect(_problem(value: 'x'), contains('value'));
      expect(_problem(value: '-5'), contains('value'));
      expect(_problem(value: '101'), contains('100'));
      expect(_problem(type: 'flat', value: '500'), isNull);
    });

    test('optional numbers must be sane when given', () {
      expect(_problem(max: '-1'), contains('maximum'));
      expect(_problem(min: 'abc'), contains('minimum'));
      expect(_problem(uses: '0'), contains('1 or more'));
      expect(_problem(uses: '2.5'), contains('whole'));
      expect(_problem(max: '500', min: '1000', uses: '50'), isNull);
    });

    test('it cannot end before it starts', () {
      expect(
        _problem(starts: DateTime(2026, 11, 10), ends: DateTime(2026, 11, 1)),
        contains('end'),
      );
      expect(
        _problem(starts: DateTime(2026, 11, 1), ends: DateTime(2026, 11, 10)),
        isNull,
      );
    });
  });

  group('couponSummary and couponUsage', () {
    test('percent with a cap and a minimum', () {
      expect(
        couponSummary(_coupon(maxDiscount: 500, minAmount: 1000)),
        '20% off, up to ₹500.00, minimum ₹1,000.00',
      );
    });

    test('a flat amount', () {
      expect(couponSummary(_coupon(type: 'flat', value: 250)), '₹250.00 off');
    });

    test('a cap is ignored on a flat coupon', () {
      expect(
        couponSummary(_coupon(type: 'flat', value: 250, maxDiscount: 10)),
        '₹250.00 off',
      );
    });

    test('usage', () {
      expect(couponUsage(_coupon(used: 3)), '3 used');
      expect(couponUsage(_coupon(used: 3, maxUses: 50)), '3 of 50 used');
    });
  });

  group('couponStatus', () {
    final now = DateTime(2026, 11, 17);

    test('paused, live and the reasons it is not live', () {
      expect(couponStatus(_coupon(active: false), now).$1, 'Paused');
      expect(couponStatus(_coupon(), now), ('Live', good));
      expect(
        couponStatus(
          _coupon(live: false, expires: DateTime(2026, 11, 1)),
          now,
        ).$1,
        'Expired',
      );
      expect(
        couponStatus(_coupon(live: false, maxUses: 5, used: 5), now).$1,
        'Used up',
      );
      expect(
        couponStatus(
          _coupon(live: false, starts: DateTime(2026, 12, 1)),
          now,
        ).$1,
        'Starts later',
      );
      expect(couponStatus(_coupon(live: false), now).$1, 'Not live');
    });
  });

  group('billingProblem', () {
    test('discounts must be 0 to 100, blank is allowed', () {
      expect(
        billingProblem(
          discountTexts: {'monthly': '0', 'yearly': '20'},
          offerLabel: '',
        ),
        isNull,
      );
      expect(
        billingProblem(discountTexts: {'yearly': ''}, offerLabel: ''),
        isNull,
      );
      expect(
        billingProblem(discountTexts: {'yearly': '120'}, offerLabel: ''),
        contains('0 to 100'),
      );
      expect(
        billingProblem(discountTexts: {'yearly': 'x'}, offerLabel: ''),
        contains('0 to 100'),
      );
    });

    test('the offer text is limited to 120 characters', () {
      expect(
        billingProblem(discountTexts: const {}, offerLabel: 'a' * 121),
        contains('120'),
      );
    });
  });

  group('models', () {
    test('AdminCoupon reads every field and keeps nulls as null', () {
      final c = AdminCoupon.fromJson({
        'id': 'c1',
        'code': 'DIWALI20',
        'type': 'percent',
        'value': '20.00',
        'max_discount': null,
        'min_amount': 1000,
        'max_uses': 50,
        'used_count': 7,
        'cycles': ['yearly'],
        'starts_at': '2026-11-01T00:00:00Z',
        'expires_at': null,
        'is_active': true,
        'live': true,
      });
      expect(c.value, 20);
      expect(c.maxDiscount, isNull);
      expect(c.minAmount, 1000);
      expect(c.maxUses, 50);
      expect(c.usedCount, 7);
      expect(c.cycles, ['yearly']);
      expect(c.startsAt, isNotNull);
      expect(c.expiresAt, isNull);
      expect(c.live, isTrue);
    });

    test('BillingSettings reads discounts, cycles and the offer', () {
      final s = BillingSettings.fromJson({
        'cycle_discounts': {'monthly': 0, 'yearly': '15.5'},
        'enabled_cycles': ['monthly', 'yearly'],
        'offer_label': 'Diwali sale',
        'offer_ends_at': '2026-11-20T18:30:00Z',
        'offer_active': true,
        'available_cycles': [
          {'key': 'monthly', 'label': 'Monthly', 'months': 1},
          {'key': 'yearly', 'label': 'Yearly', 'months': 12},
        ],
      });
      expect(s.cycleDiscounts['yearly'], 15.5);
      expect(s.enabledCycles, ['monthly', 'yearly']);
      expect(s.offerLabel, 'Diwali sale');
      expect(s.offerEndsAt, isNotNull);
      expect(s.offerActive, isTrue);
      expect(s.availableCycles.last.months, 12);
    });

    test('empty settings are safe', () {
      final s = BillingSettings.fromJson({});
      expect(s.availableCycles, isEmpty);
      expect(s.offerEndsAt, isNull);
      expect(s.offerActive, isFalse);
    });
  });

  test('apiDay pads month and day', () {
    expect(apiDay(DateTime(2026, 3, 5)), '2026-03-05');
  });
}
