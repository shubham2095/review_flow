import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/admin_pricing_models.dart';
import '../services/admin_service.dart';
import '../services/api_service.dart';
import '../theme/brand.dart';
import '../widgets/admin_ui.dart';
import '../widgets/date_format.dart';
import '../widgets/fade_in.dart';
import '../widgets/invoice_format.dart';
import '../widgets/skeleton.dart';
import '../widgets/tab_label.dart';

// ---- Pure helpers (tested) ----

final _codePattern = RegExp(r'^[A-Z0-9_-]+$');

/// What is wrong with a coupon form, or null. [code] is checked after it is
/// trimmed and upper-cased, the way the server does it.
String? couponProblem({
  required String code,
  required String type,
  required String valueText,
  String maxDiscountText = '',
  String minAmountText = '',
  String maxUsesText = '',
  DateTime? startsAt,
  DateTime? expiresAt,
}) {
  final c = code.trim().toUpperCase();
  if (c.isEmpty) return 'Write the coupon code.';
  if (c.length > 40) return 'Keep the code to 40 characters or fewer.';
  if (!_codePattern.hasMatch(c)) {
    return 'Use only letters, numbers, dash and underscore in the code.';
  }
  final value = double.tryParse(valueText.trim());
  if (value == null || value < 0) return 'Write the discount value.';
  if (type == 'percent' && value > 100) {
    return 'A percent discount cannot be more than 100.';
  }
  for (final (text, name) in [
    (maxDiscountText, 'maximum discount'),
    (minAmountText, 'minimum amount'),
  ]) {
    if (text.trim().isEmpty) continue;
    final n = double.tryParse(text.trim());
    if (n == null || n < 0) return 'The $name must be 0 or more.';
  }
  if (maxUsesText.trim().isNotEmpty) {
    final n = int.tryParse(maxUsesText.trim());
    if (n == null || n < 1) return 'Uses must be a whole number, 1 or more.';
  }
  if (startsAt != null && expiresAt != null && expiresAt.isBefore(startsAt)) {
    return 'The coupon cannot end before it starts.';
  }
  return null;
}

/// "20% off, up to ₹500, minimum ₹1,000" for a coupon.
String couponSummary(AdminCoupon c) {
  final parts = <String>[
    c.type == 'flat'
        ? '${invoiceMoney(c.value)} off'
        : '${invoiceNumber(c.value)}% off',
  ];
  if (c.type == 'percent' && c.maxDiscount != null) {
    parts.add('up to ${invoiceMoney(c.maxDiscount!)}');
  }
  if (c.minAmount != null && c.minAmount! > 0) {
    parts.add('minimum ${invoiceMoney(c.minAmount!)}');
  }
  return parts.join(', ');
}

/// "3 of 50 used", "3 used".
String couponUsage(AdminCoupon c) => c.maxUses == null
    ? '${c.usedCount} used'
    : '${c.usedCount} of ${c.maxUses} used';

/// A coupon's state as a word and a colour.
(String, Color) couponStatus(AdminCoupon c, [DateTime? now]) {
  final at = now ?? DateTime.now();
  if (!c.isActive) return ('Paused', muted);
  if (c.live) return ('Live', good);
  if (c.expiresAt != null && c.expiresAt!.isBefore(at)) {
    return ('Expired', bad);
  }
  if (c.maxUses != null && c.usedCount >= c.maxUses!) {
    return ('Used up', warn);
  }
  if (c.startsAt != null && c.startsAt!.isAfter(at)) {
    return ('Starts later', warn);
  }
  return ('Not live', warn);
}

/// What is wrong with the pricing settings, or null.
String? billingProblem({
  required Map<String, String> discountTexts,
  required String offerLabel,
}) {
  for (final e in discountTexts.entries) {
    final t = e.value.trim();
    if (t.isEmpty) continue;
    final n = double.tryParse(t);
    if (n == null || n < 0 || n > 100) {
      return 'Each discount must be a number from 0 to 100.';
    }
  }
  if (offerLabel.trim().length > 120) {
    return 'Keep the offer text to 120 characters or fewer.';
  }
  return null;
}

String _num(double? v) => v == null ? '' : invoiceNumber(v);

/// Pricing & coupons for the super admin: discount codes, and the pricing
/// page's cycle discounts and launch offer.
class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  int _tab = 0;
  final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: TabLabel('Coupons')),
                  ButtonSegment(value: 1, label: TabLabel('Pricing page')),
                ],
                selected: {_tab},
                onSelectionChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _tab = v.first;
                    _visited.add(_tab);
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                const AdminCouponsTab(),
                if (_visited.contains(1))
                  const AdminBillingSettingsTab()
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coupons

/// The discount codes, with new, edit, pause and delete.
class AdminCouponsTab extends StatefulWidget {
  const AdminCouponsTab({super.key});

  @override
  State<AdminCouponsTab> createState() => _AdminCouponsTabState();
}

class _AdminCouponsTabState extends State<AdminCouponsTab> {
  List<AdminCoupon> _coupons = [];
  List<BillingCycleInfo> _cycles = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final coupons = await AdminService.coupons();
      // The cycle list only fills the form's chips: do without it if it fails.
      var cycles = _cycles;
      try {
        cycles = (await AdminService.billingSettings()).availableCycles;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _coupons = coupons;
        _cycles = cycles;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    NoticeScope.show(context, text);
  }

  Future<void> _form([AdminCoupon? coupon]) async {
    final saved = await showAdminSheet<bool>(
      context,
      (_) => _CouponForm(coupon: coupon, cycles: _cycles),
    );
    if (saved == true) {
      _snack(coupon == null ? 'Coupon created' : 'Coupon updated');
      await _load();
    }
  }

  Future<void> _togglePause(AdminCoupon c) async {
    setState(() => _busy.add(c.id));
    try {
      await AdminService.saveCoupon(c.id, {
        'code': c.code,
        'type': c.type,
        'value': c.value,
        'max_discount': c.maxDiscount,
        'min_amount': c.minAmount,
        'max_uses': c.maxUses,
        'cycles': c.cycles == null || c.cycles!.isEmpty ? null : c.cycles,
        'starts_at': c.startsAt == null ? null : apiDay(c.startsAt!),
        'expires_at': c.expiresAt == null ? null : apiDay(c.expiresAt!),
        'is_active': !c.isActive,
      });
      _snack(c.isActive ? 'Coupon paused' : 'Coupon switched on');
      await _load();
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  Future<void> _delete(AdminCoupon c) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete ${c.code}?',
      text: 'Pause it instead to keep its use count.',
      action: 'Delete',
      danger: true,
    );
    if (!ok) return;
    setState(() => _busy.add(c.id));
    try {
      await AdminService.deleteCoupon(c.id);
      _snack('Coupon deleted');
      await _load();
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  Widget _card(AdminCoupon c, int i) {
    final (label, color) = couponStatus(c);
    final cycles = c.cycles == null || c.cycles!.isEmpty
        ? 'All cycles'
        : c.cycles!
              .map(
                (k) => _cycles
                    .firstWhere(
                      (x) => x.key == k,
                      orElse: () => BillingCycleInfo(key: k, label: k),
                    )
                    .label,
              )
              .join(', ');
    final dates = [
      if (c.startsAt != null) 'from ${fmtDate(c.startsAt!)}',
      if (c.expiresAt != null) 'until ${fmtDate(c.expiresAt!)}',
    ].join(' ');
    return FadeIn(
      delay: i < 8 ? i * 50 : 0,
      child: Semantics(
        container: true,
        label:
            '${c.code}, $label, ${couponSummary(c)}, ${couponUsage(c)}, $cycles'
            '${dates.isEmpty ? '' : ', $dates'}',
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: cardDecoration(),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AdminBadge(label, color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        couponSummary(c),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: inkSoft,
                        ),
                      ),
                      Text(
                        '${couponUsage(c)} · $cycles',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                      if (dates.isNotEmpty)
                        Text(
                          dates,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_busy.contains(c.id))
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'More for ${c.code}',
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _form(c);
                      case 'toggle':
                        _togglePause(c);
                      case 'delete':
                        _delete(c);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit coupon'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(c.isActive ? 'Pause' : 'Switch on'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: bad)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(),
        backgroundColor: royalIndigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New coupon'),
      ),
      body: RefreshIndicator(
        color: brand,
        onRefresh: _load,
        child: _loading
            ? const SkeletonList(count: 4, itemHeight: 92)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_error != null)
                    AdminMessage(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load coupons',
                      text: _error!,
                      onRetry: _load,
                    )
                  else if (_coupons.isEmpty)
                    const AdminMessage(
                      icon: Icons.local_offer_outlined,
                      title: 'No coupons yet',
                      text: 'A coupon takes a percent or an amount off a plan.',
                    )
                  else
                    for (var i = 0; i < _coupons.length; i++)
                      _card(_coupons[i], i),
                ],
              ),
      ),
    );
  }
}

/// A date as the server wants it: `2026-11-17`.
String apiDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _CouponForm extends StatefulWidget {
  const _CouponForm({required this.coupon, required this.cycles});

  final AdminCoupon? coupon;
  final List<BillingCycleInfo> cycles;

  @override
  State<_CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<_CouponForm> {
  late final _code = TextEditingController(text: widget.coupon?.code ?? '');
  late final _value = TextEditingController(text: _num(widget.coupon?.value));
  late final _maxDiscount = TextEditingController(
    text: _num(widget.coupon?.maxDiscount),
  );
  late final _minAmount = TextEditingController(
    text: _num(widget.coupon?.minAmount),
  );
  late final _maxUses = TextEditingController(
    text: widget.coupon?.maxUses == null ? '' : '${widget.coupon!.maxUses}',
  );
  late String _type = widget.coupon?.type ?? 'percent';
  late final Set<String> _cycleKeys = {...?widget.coupon?.cycles};
  late DateTime? _starts = widget.coupon?.startsAt;
  late DateTime? _expires = widget.coupon?.expiresAt;
  late bool _active = widget.coupon?.isActive ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _maxDiscount.dispose();
    _minAmount.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  void _message(String text) => NoticeScope.show(context, text);

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _starts : _expires) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _starts = picked;
      } else {
        _expires = picked;
      }
    });
  }

  Future<void> _save() async {
    final problem = couponProblem(
      code: _code.text,
      type: _type,
      valueText: _value.text,
      maxDiscountText: _maxDiscount.text,
      minAmountText: _minAmount.text,
      maxUsesText: _maxUses.text,
      startsAt: _starts,
      expiresAt: _expires,
    );
    if (problem != null) {
      HapticFeedback.lightImpact();
      _message(problem);
      return;
    }
    double? numberOrNull(String s) =>
        s.trim().isEmpty ? null : double.parse(s.trim());
    setState(() => _busy = true);
    try {
      // Blank fields are sent as null so that an edit really clears them.
      await AdminService.saveCoupon(widget.coupon?.id, {
        'code': _code.text.trim().toUpperCase(),
        'type': _type,
        'value': double.parse(_value.text.trim()),
        'max_discount': _type == 'percent'
            ? numberOrNull(_maxDiscount.text)
            : null,
        'min_amount': numberOrNull(_minAmount.text),
        'max_uses': _maxUses.text.trim().isEmpty
            ? null
            : int.parse(_maxUses.text.trim()),
        'cycles': _cycleKeys.isEmpty ? null : _cycleKeys.toList(),
        'starts_at': _starts == null ? null : apiDay(_starts!),
        'expires_at': _expires == null ? null : apiDay(_expires!),
        'is_active': _active,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _message(friendlyException(e).message);
      }
    }
  }

  Widget _dateButton(String label, DateTime? value, bool start) {
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label: ${value == null ? 'not set' : fmtDate(value)}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : () => _pick(start),
          child: InputDecorator(
            decoration: adminInput(label),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null ? 'Not set' : fmtDate(value),
                    style: GoogleFonts.plusJakartaSans(
                      color: value == null ? muted : ink,
                    ),
                  ),
                ),
                if (value != null)
                  InkWell(
                    onTap: () => setState(() {
                      if (start) {
                        _starts = null;
                      } else {
                        _expires = null;
                      }
                    }),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 18, color: muted),
                    ),
                  )
                else
                  const Icon(Icons.event_rounded, size: 18, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSheetHeader(
              widget.coupon == null ? 'New coupon' : 'Edit coupon',
            ),
            TextField(
              controller: _code,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              maxLength: 40,
              decoration: adminInput('Code', hint: 'DIWALI20'),
            ),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'percent', label: TabLabel('Percent off')),
                ButtonSegment(value: 'flat', label: TabLabel('Amount off')),
              ],
              selected: {_type},
              onSelectionChanged: _busy
                  ? null
                  : (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _value,
              enabled: !_busy,
              keyboardType: decimal,
              decoration: adminInput(
                _type == 'percent' ? 'Discount %' : 'Discount amount (₹)',
              ),
            ),
            if (_type == 'percent') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _maxDiscount,
                enabled: !_busy,
                keyboardType: decimal,
                decoration: adminInput(
                  'Maximum discount (₹, optional)',
                  hint: 'No cap',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAmount,
                    enabled: !_busy,
                    keyboardType: decimal,
                    decoration: adminInput('Minimum amount (₹)', hint: 'None'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxUses,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: adminInput('Total uses', hint: 'Unlimited'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _dateButton('Starts', _starts, true),
                const SizedBox(width: 12),
                _dateButton('Ends', _expires, false),
              ],
            ),
            if (widget.cycles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  'Works on',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Text(
                  _cycleKeys.isEmpty
                      ? 'All billing cycles. Tick some to limit it.'
                      : 'Only the ticked billing cycles.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in widget.cycles)
                    FilterChip(
                      label: Text(c.label),
                      selected: _cycleKeys.contains(c.key),
                      onSelected: _busy
                          ? null
                          : (v) => setState(() {
                              if (v) {
                                _cycleKeys.add(c.key);
                              } else {
                                _cycleKeys.remove(c.key);
                              }
                            }),
                    ),
                ],
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('A paused coupon cannot be used'),
              value: _active,
              onChanged: _busy ? null : (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.coupon == null ? 'Create coupon' : 'Save coupon',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pricing page settings

/// Per-cycle discounts, which cycles the pricing page shows, and the
/// limited-time launch offer.
class AdminBillingSettingsTab extends StatefulWidget {
  const AdminBillingSettingsTab({super.key});

  @override
  State<AdminBillingSettingsTab> createState() =>
      _AdminBillingSettingsTabState();
}

class _AdminBillingSettingsTabState extends State<AdminBillingSettingsTab> {
  BillingSettings? _settings;
  final Map<String, TextEditingController> _discounts = {};
  final Set<String> _enabled = {};
  final _offerLabel = TextEditingController();
  DateTime? _offerEnds;
  bool _offerActive = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _discounts.values) {
      c.dispose();
    }
    _offerLabel.dispose();
    super.dispose();
  }

  void _fill(BillingSettings s) {
    for (final c in _discounts.values) {
      c.dispose();
    }
    _discounts
      ..clear()
      ..addEntries([
        for (final cycle in s.availableCycles)
          MapEntry(
            cycle.key,
            TextEditingController(text: _num(s.cycleDiscounts[cycle.key] ?? 0)),
          ),
      ]);
    _enabled
      ..clear()
      ..addAll(s.enabledCycles);
    _offerLabel.text = s.offerLabel;
    _offerEnds = s.offerEndsAt?.toLocal();
    _offerActive = s.offerActive;
  }

  Future<void> _load() async {
    try {
      final s = await AdminService.billingSettings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _fill(s);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    NoticeScope.show(context, text);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _offerEnds ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_offerEnds ?? now),
    );
    if (!mounted) return;
    setState(() {
      _offerEnds = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  Future<void> _save() async {
    final problem = billingProblem(
      discountTexts: {for (final e in _discounts.entries) e.key: e.value.text},
      offerLabel: _offerLabel.text,
    );
    if (problem != null) {
      HapticFeedback.lightImpact();
      _snack(problem);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await AdminService.saveBillingSettings({
        'cycle_discounts': {
          for (final e in _discounts.entries)
            e.key: e.value.text.trim().isEmpty
                ? 0
                : double.parse(e.value.text.trim()),
        },
        'enabled_cycles': [
          for (final c in _settings!.availableCycles)
            if (_enabled.contains(c.key)) c.key,
        ],
        'offer_label': _offerLabel.text.trim().isEmpty
            ? null
            : _offerLabel.text.trim(),
        'offer_ends_at': _offerEnds?.toUtc().toIso8601String(),
        'offer_active': _offerActive,
      });
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _fill(saved);
      });
      _snack('Pricing settings saved');
    } catch (e) {
      _snack(friendlyException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonList(count: 3, itemHeight: 120);
    final s = _settings;
    if (_error != null || s == null) {
      return ListView(
        children: [
          AdminMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load pricing settings',
            text: _error ?? '',
            onRetry: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      );
    }
    return RefreshIndicator(
      color: brand,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Billing cycles',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(
              'The discount for paying ahead, and whether the pricing page '
              'shows the cycle.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
            ),
          ),
          for (final c in s.availableCycles)
            Container(
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
                          c.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        Text(
                          '${c.months} ${c.months == 1 ? 'month' : 'months'}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                        Semantics(
                          label: 'Show ${c.label} on the pricing page',
                          child: Row(
                            children: [
                              Switch(
                                value: _enabled.contains(c.key),
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() {
                                        if (v) {
                                          _enabled.add(c.key);
                                        } else {
                                          _enabled.remove(c.key);
                                        }
                                      }),
                              ),
                              Text(
                                'Show',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _discounts[c.key],
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: adminInput('Discount %'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              'Launch offer',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ink,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(
              'A limited-time banner with a countdown on the pricing page.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: muted),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _offerLabel,
                  enabled: !_saving,
                  maxLength: 120,
                  decoration: adminInput(
                    'Offer text',
                    hint: 'Diwali sale: extra 20% off',
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  button: true,
                  label:
                      'Offer ends: ${_offerEnds == null ? 'not set' : fmtDateTime(_offerEnds!)}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _saving ? null : _pickEnd,
                    child: InputDecorator(
                      decoration: adminInput('Offer ends'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _offerEnds == null
                                  ? 'Not set'
                                  : fmtDateTime(_offerEnds!),
                              style: GoogleFonts.plusJakartaSans(
                                color: _offerEnds == null ? muted : ink,
                              ),
                            ),
                          ),
                          if (_offerEnds != null)
                            InkWell(
                              onTap: () => setState(() => _offerEnds = null),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: muted,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.event_rounded,
                              size: 18,
                              color: muted,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offer is on'),
                  subtitle: const Text('Shows the banner on the pricing page'),
                  value: _offerActive,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _offerActive = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save pricing settings'),
          ),
        ],
      ),
    );
  }
}
