import 'gbp_models.dart' show asDate, asDouble, asInt, asMap, asMaps, asStr;

/// `percent` (a % off) or `flat` (an amount off).
const couponTypes = ['percent', 'flat'];

/// A discount code: GET /admin/coupons.
class AdminCoupon {
  const AdminCoupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.maxDiscount,
    this.minAmount,
    this.maxUses,
    this.usedCount = 0,
    this.cycles,
    this.startsAt,
    this.expiresAt,
    this.isActive = true,
    this.live = false,
  });

  factory AdminCoupon.fromJson(Map<String, dynamic> j) => AdminCoupon(
    id: asStr(j['id']),
    code: asStr(j['code']),
    type: asStr(j['type']) == 'flat' ? 'flat' : 'percent',
    value: asDouble(j['value']),
    maxDiscount: j['max_discount'] == null ? null : asDouble(j['max_discount']),
    minAmount: j['min_amount'] == null ? null : asDouble(j['min_amount']),
    maxUses: j['max_uses'] == null ? null : asInt(j['max_uses']),
    usedCount: asInt(j['used_count']),
    cycles: j['cycles'] is List
        ? (j['cycles'] as List).map((e) => e.toString()).toList()
        : null,
    startsAt: asDate(j['starts_at']),
    expiresAt: asDate(j['expires_at']),
    isActive: j['is_active'] != false,
    live: j['live'] == true,
  );

  final String id;
  final String code;
  final String type;
  final double value;

  /// For a percent coupon: the most it can take off. Null means no cap.
  final double? maxDiscount;

  /// The least a purchase must cost. Null means no minimum.
  final double? minAmount;

  /// How many times it can be used in all. Null means unlimited.
  final int? maxUses;
  final int usedCount;

  /// The billing cycles it works on; null or empty means all of them.
  final List<String>? cycles;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isActive;

  /// The server's verdict: switched on, inside its dates and not used up.
  final bool live;
}

/// A billing cycle the system supports (monthly, yearly...).
class BillingCycleInfo {
  const BillingCycleInfo({
    required this.key,
    required this.label,
    this.months = 1,
  });

  factory BillingCycleInfo.fromJson(Map<String, dynamic> j) => BillingCycleInfo(
    key: asStr(j['key']),
    label: asStr(j['label']),
    months: asInt(j['months']) == 0 ? 1 : asInt(j['months']),
  );

  final String key;
  final String label;
  final int months;
}

/// GET /admin/billing-settings: the pricing page controls.
class BillingSettings {
  const BillingSettings({
    this.cycleDiscounts = const {},
    this.enabledCycles = const [],
    this.offerLabel = '',
    this.offerEndsAt,
    this.offerActive = false,
    this.availableCycles = const [],
  });

  factory BillingSettings.fromJson(Map<String, dynamic> j) {
    final discounts = asMap(j['cycle_discounts']);
    return BillingSettings(
      cycleDiscounts: {
        for (final e in discounts.entries) e.key: asDouble(e.value),
      },
      enabledCycles: j['enabled_cycles'] is List
          ? (j['enabled_cycles'] as List).map((e) => e.toString()).toList()
          : const [],
      offerLabel: asStr(j['offer_label']),
      offerEndsAt: asDate(j['offer_ends_at']),
      offerActive: j['offer_active'] == true,
      availableCycles: asMaps(
        j['available_cycles'],
      ).map(BillingCycleInfo.fromJson).toList(),
    );
  }

  /// Discount % by cycle key.
  final Map<String, double> cycleDiscounts;

  /// The cycles the pricing page shows.
  final List<String> enabledCycles;
  final String offerLabel;
  final DateTime? offerEndsAt;
  final bool offerActive;
  final List<BillingCycleInfo> availableCycles;
}
