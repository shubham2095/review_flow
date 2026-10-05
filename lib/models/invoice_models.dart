// Laravel decimal values aksar string ("1180.00") mein aate hain, isliye dono handle karte hain.
double _money(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String _s(dynamic v) => v?.toString() ?? '';

String _date(dynamic v) {
  final t = _s(v);
  return t.length >= 10 ? t.substring(0, 10) : t;
}

class InvoiceSummary {
  InvoiceSummary.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        number = _s(j['invoice_number']),
        clientName = _s(j['client_name']),
        issueDate = _date(j['issue_date']),
        dueDate = _date(j['due_date']),
        status = _s(j['status']).isEmpty ? 'DRAFT' : _s(j['status']),
        total = _money(j['total']);

  final int id;
  final String number;
  final String clientName;
  final String issueDate;
  final String dueDate;
  final String status;
  final double total;
}

class InvoiceStats {
  InvoiceStats.fromJson(Map<String, dynamic> j)
      : outstanding = _money(j['outstanding']),
        paidThisMonth = _money(j['paid_this_month']),
        drafts = _i(j['drafts']);

  final double outstanding;
  final double paidThisMonth;
  final int drafts;
}

class InvoiceItemLine {
  InvoiceItemLine.fromJson(Map<String, dynamic> j)
      : description = _s(j['description']),
        quantity = _money(j['quantity']),
        unitPrice = _money(j['unit_price']),
        gstPercent = _money(j['gst_percent']),
        amount = _money(j['amount']);

  final String description;
  final double quantity;
  final double unitPrice;
  final double gstPercent;
  final double amount;
}

class InvoiceDetail {
  InvoiceDetail.fromJson(Map<String, dynamic> wrapper)
      : id = _i((wrapper['invoice'] as Map<String, dynamic>)['id']),
        number = _s((wrapper['invoice'] as Map<String, dynamic>)['invoice_number']),
        clientName = _s(((wrapper['invoice'] as Map<String, dynamic>)['client'] as Map<String, dynamic>?)?['name']),
        issueDate = _date((wrapper['invoice'] as Map<String, dynamic>)['issue_date']),
        dueDate = _date((wrapper['invoice'] as Map<String, dynamic>)['due_date']),
        status = _s((wrapper['invoice'] as Map<String, dynamic>)['status']),
        subtotal = _money((wrapper['invoice'] as Map<String, dynamic>)['subtotal']),
        gstTotal = _money((wrapper['invoice'] as Map<String, dynamic>)['gst_total']),
        total = _money((wrapper['invoice'] as Map<String, dynamic>)['total']),
        notes = _s((wrapper['invoice'] as Map<String, dynamic>)['notes']),
        items = (((wrapper['invoice'] as Map<String, dynamic>)['items'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(InvoiceItemLine.fromJson)
            .toList();

  final int id;
  final String number;
  final String clientName;
  final String issueDate;
  final String dueDate;
  final String status;
  final double subtotal;
  final double gstTotal;
  final double total;
  final String notes;
  final List<InvoiceItemLine> items;
}

class CustomerOption {
  CustomerOption.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']);

  final int id;
  final String name;
}

const invoiceStatusLabels = {
  'DRAFT': 'Draft',
  'SENT': 'Sent',
  'PAID': 'Paid',
  'OVERDUE': 'Overdue',
};
