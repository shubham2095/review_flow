int _i(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toInt() ?? 0;

String _s(dynamic v) => v?.toString() ?? '';

double _money(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

String _date(dynamic v) {
  final t = _s(v);
  return t.length >= 10 ? t.substring(0, 10) : t;
}

class Customer {
  Customer.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']),
        email = _s(j['email']),
        phone = _s(j['phone']),
        gstin = _s(j['gstin']),
        billingAddress = _s(j['billing_address']),
        invoicesCount = _i(j['invoices_count']);

  final int id;
  final String name;
  final String email;
  final String phone;
  final String gstin;
  final String billingAddress;
  final int invoicesCount;
}

class Expense {
  Expense.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        date = _date(j['date']),
        description = _s(j['description']),
        category = _s(j['category']),
        method = _s(j['method']).isEmpty ? 'OTHER' : _s(j['method']),
        amount = _money(j['amount']);

  final int id;
  final String date;
  final String description;
  final String category;
  final String method;
  final double amount;
}

class ExpenseBoard {
  ExpenseBoard({required this.expenses, required this.spentThisMonth, required this.count});

  factory ExpenseBoard.fromJson(Map<String, dynamic> j) {
    final stats = j['stats'] as Map<String, dynamic>? ?? {};
    return ExpenseBoard(
      expenses: ((j['expenses'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(Expense.fromJson)
          .toList(),
      spentThisMonth: _money(stats['spent_this_month']),
      count: _i(stats['count']),
    );
  }

  final List<Expense> expenses;
  final double spentThisMonth;
  final int count;
}

const expenseMethodLabels = {
  'CASH': 'Cash',
  'BANK': 'Bank',
  'UPI': 'UPI',
  'CARD': 'Card',
  'OTHER': 'Other',
};
