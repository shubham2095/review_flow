import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/invoicing_models.dart';
import '../services/access_problem.dart';
import '../services/api_service.dart';
import '../services/invoicing_service.dart';
import '../theme/brand.dart';
import '../widgets/date_format.dart';
import '../widgets/invoice_format.dart';
import '../widgets/sheet_notice.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_view.dart';
import '../widgets/wa_ui.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "November 2026".
String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// The first day of the month [delta] months from [d] (negative for earlier).
DateTime shiftMonth(DateTime d, int delta) => DateTime(d.year, d.month + delta);

bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// "Cash", "Bank transfer", "UPI", "Card" or "Other".
String expenseMethodLabel(String method) => switch (method.toUpperCase()) {
  'CASH' => 'Cash',
  'BANK' => 'Bank transfer',
  'UPI' => 'UPI',
  'CARD' => 'Card',
  'OTHER' => 'Other',
  _ =>
    method.isEmpty
        ? 'Other'
        : method[0].toUpperCase() + method.substring(1).toLowerCase(),
};

/// The sum of the amounts shown.
double expenseTotal(List<InvoiceExpenseRow> rows) =>
    rows.fold<double>(0, (s, r) => s + r.amount);

/// What is wrong with an expense, or null.
String? expenseProblem({required String description, required double? amount}) {
  if (description.trim().isEmpty) return 'Write what the money was spent on.';
  if (amount == null || amount < 0) return 'Write the amount (0 or more).';
  return null;
}

/// Money you spent on the business: a month at a time, with a total, and a
/// way to add or delete an expense. A tab of the Invoicing page.
class InvoiceExpensesTab extends StatefulWidget {
  const InvoiceExpensesTab({super.key});

  @override
  State<InvoiceExpensesTab> createState() => _InvoiceExpensesTabState();
}

class _InvoiceExpensesTabState extends State<InvoiceExpensesTab> {
  ExpenseList? _data;
  String _currency = 'INR';

  /// The month shown, or null for every month.
  DateTime? _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  bool _refreshing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  Future<void> _load({bool first = false}) async {
    if (!first) setState(() => _refreshing = true);
    final asked = _month;
    try {
      final data = await InvoicingService.expenses(month: asked);
      var currency = _currency;
      if (first) {
        try {
          currency = (await InvoicingService.profile()).currency;
        } catch (_) {}
      }
      // A later tap on another month wins.
      if (!mounted || asked != _month) return;
      setState(() {
        _data = data;
        _currency = currency;
        _error = null;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _setMonth(DateTime? m) {
    HapticFeedback.selectionClick();
    setState(() => _month = m);
    _load();
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ExpenseSheet(
        categories: {
          for (final r in _data?.rows ?? const <InvoiceExpenseRow>[])
            if (r.category.isNotEmpty) r.category,
        }.toList(),
      ),
    );
    if (saved != true || !mounted) return;
    showToast(context, 'Expense added.');
    _load();
  }

  Future<void> _delete(InvoiceExpenseRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: Text(
          '${r.description}, ${invoiceMoney(r.amount, _currency)}. This cannot '
          'be undone from the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final message = await InvoicingService.deleteExpense(r.id);
      if (!mounted) return;
      showToast(context, message);
      _load();
    } catch (e) {
      if (mounted) showToast(context, errorLine(e));
    }
  }

  Widget _monthBar() {
    final m = _month;
    final now = DateTime.now();
    return Row(
      children: [
        if (m != null) ...[
          IconButton(
            tooltip: 'Earlier month',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _setMonth(shiftMonth(m, -1)),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                monthLabel(m),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Later month',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: sameMonth(m, now)
                ? null
                : () => _setMonth(shiftMonth(m, 1)),
          ),
        ] else
          Expanded(
            child: Text(
              'All months',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
        ChoiceChip(
          label: const Text('All'),
          selected: m == null,
          onSelected: (_) =>
              _setMonth(m == null ? DateTime(now.year, now.month) : null),
        ),
      ],
    );
  }

  Widget _row(InvoiceExpenseRow r) {
    final date = r.date == null ? '' : fmtDate(r.date!);
    final money = invoiceMoney(r.amount, _currency);
    return Semantics(
      container: true,
      label:
          '${r.description}, $money, ${expenseMethodLabel(r.method)}'
          '${r.category.isEmpty ? '' : ', ${r.category}'}'
          '${date.isEmpty ? '' : ', $date'}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 2, 10),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        InfoChip(expenseMethodLabel(r.method)),
                        if (r.category.isNotEmpty)
                          InfoChip(r.category, color: brand),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Text(
                money,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More for ${r.description}',
              onSelected: (_) => _delete(r),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const SkeletonList(count: 4, itemHeight: 82, headerHeight: 96);
    }
    final error = _error;
    final data = _data;
    if (error != null && data == null) {
      final access = accessProblem(error);
      return Center(
        child: SingleChildScrollView(
          child: access != null
              ? StateView(
                  icon: access.icon,
                  title: access.title,
                  text: access.text,
                )
              : StateView.error(
                  title: 'Could not load expenses',
                  text: friendlyException(error).message,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load(first: true);
                  },
                ),
        ),
      );
    }
    final rows = data!.rows;
    // Rows: the two totals, the month bar, the count and Add button, then
    // one row per expense (or one empty note), built lazily.
    const lead = 3;
    return RefreshIndicator(
      color: brand,
      onRefresh: () => _load(),
      child: ContentWidth(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: lead + (rows.isEmpty ? 1 : rows.length),
          itemBuilder: (_, i) {
            switch (i) {
              case 0:
                return Row(
                  children: [
                    Expanded(
                      child: _AmountTile(
                        label: 'Spent this month',
                        value: invoiceMoney(data.spentThisMonth, _currency),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AmountTile(
                        label: _month == null
                            ? 'Total, all months'
                            : 'Total, ${monthLabel(_month!)}',
                        value: invoiceMoney(expenseTotal(rows), _currency),
                        icon: Icons.summarize_outlined,
                      ),
                    ),
                  ],
                );
              case 1:
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _monthBar(),
                );
              case 2:
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '${rows.length} ${rows.length == 1 ? 'expense' : 'expenses'}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: muted,
                              ),
                            ),
                            if (_refreshing) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add expense'),
                      ),
                    ],
                  ),
                );
            }
            if (rows.isEmpty) {
              return StateView(
                icon: Icons.payments_outlined,
                title: 'No expenses',
                text: _month == null
                    ? 'Add the money you spend on the business.'
                    : 'Nothing was spent in ${monthLabel(_month!)}.',
              );
            }
            return _row(rows[i - lead]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _body();
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: brand),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds an expense. [categories] are ones already used, to tap instead of
/// typing. Pops with true when saved.
class ExpenseSheet extends StatefulWidget {
  const ExpenseSheet({super.key, this.categories = const []});

  final List<String> categories;

  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  DateTime _date = DateTime.now();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _amount = TextEditingController();
  String _method = 'CASH';
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _description.dispose();
    _category.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final problem = expenseProblem(
      description: _description.text,
      amount: amount,
    );
    if (problem != null) {
      HapticFeedback.lightImpact();
      setState(() => _notice = problem);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await InvoicingService.addExpense(
        date: _date,
        description: _description.text.trim(),
        category: _category.text.trim(),
        method: _method,
        amount: amount!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _busy = false;
        _notice = errorLine(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Add an expense',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Date: ${fmtDate(_date)}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _busy ? null : _pickDate,
              child: InputDecorator(
                decoration: waInputDecoration('Date'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fmtDate(_date),
                        style: GoogleFonts.plusJakartaSans(color: ink),
                      ),
                    ),
                    const Icon(Icons.event_rounded, size: 18, color: muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_busy,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: waInputDecoration(
              'What was it for?',
              hint: 'Office rent, Google Ads...',
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _category,
            enabled: !_busy,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: waInputDecoration('Category (optional)'),
          ),
          if (widget.categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in widget.categories)
                    ActionChip(
                      label: Text(c),
                      tooltip: 'Use $c',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _category.text = c),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: waInputDecoration('Amount'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _method,
                  isExpanded: true,
                  decoration: waInputDecoration('Paid by'),
                  items: [
                    for (final m in expenseMethods)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          expenseMethodLabel(m),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _method = v ?? 'CASH'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SheetNotice(_notice),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? Semantics(
                    label: 'Saving',
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Text('Add expense'),
          ),
        ],
      ),
    );
  }
}
