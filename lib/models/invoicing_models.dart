import 'gbp_models.dart' show asDate, asDouble, asInt, asMap, asMaps, asStr;

/// `DRAFT`, `SENT`, `OVERDUE` or `PAID` as the server writes them.
const invoiceStatuses = ['DRAFT', 'SENT', 'OVERDUE', 'PAID'];

/// The three numbers on top of the invoice list.
class InvoiceStats {
  const InvoiceStats({
    this.outstanding = 0,
    this.paidThisMonth = 0,
    this.drafts = 0,
  });

  factory InvoiceStats.fromJson(Map<String, dynamic> j) => InvoiceStats(
    outstanding: asDouble(j['outstanding']),
    paidThisMonth: asDouble(j['paid_this_month']),
    drafts: asInt(j['drafts']),
  );

  /// Sent or overdue, not paid yet.
  final double outstanding;
  final double paidThisMonth;
  final int drafts;
}

/// One row of GET /invoicing/invoices.
class InvoiceRow {
  const InvoiceRow({
    required this.id,
    required this.number,
    required this.customerName,
    required this.status,
    required this.total,
    this.issueDate,
    this.dueDate,
  });

  factory InvoiceRow.fromJson(Map<String, dynamic> j) => InvoiceRow(
    id: asStr(j['id']),
    number: asStr(j['invoice_number']),
    customerName: asStr(j['customer_name']),
    status: asStr(j['status']),
    total: asDouble(j['total']),
    issueDate: asDate(j['issue_date']),
    dueDate: asDate(j['due_date']),
  );

  final String id;
  final String number;
  final String customerName;
  final String status;
  final double total;
  final DateTime? issueDate;
  final DateTime? dueDate;
}

/// GET /invoicing/invoices: the rows and the totals above them.
class InvoiceList {
  const InvoiceList({required this.rows, required this.stats});

  factory InvoiceList.fromJson(Map<String, dynamic> j) => InvoiceList(
    rows: asMaps(j['invoices']).map(InvoiceRow.fromJson).toList(),
    stats: InvoiceStats.fromJson(asMap(j['stats'])),
  );

  final List<InvoiceRow> rows;
  final InvoiceStats stats;
}

/// A line on a saved invoice.
class InvoiceLine {
  const InvoiceLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.gstPercent,
    required this.amount,
  });

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
    description: asStr(j['description']),
    quantity: asDouble(j['quantity']),
    unitPrice: asDouble(j['unit_price']),
    gstPercent: asDouble(j['gst_percent']),
    amount: asDouble(j['amount']),
  );

  final String description;
  final double quantity;
  final double unitPrice;
  final double gstPercent;

  /// The line total with GST.
  final double amount;
}

/// A saved invoice: GET /invoicing/invoices/{id}.
class InvoiceDetail {
  const InvoiceDetail({
    required this.id,
    required this.number,
    required this.status,
    required this.customerId,
    required this.customerName,
    required this.subtotal,
    required this.gstTotal,
    required this.total,
    this.issueDate,
    this.dueDate,
    this.notes = '',
    this.paidAt,
    this.lines = const [],
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> j) {
    final customer = asMap(j['customer']);
    return InvoiceDetail(
      id: asStr(j['id']),
      number: asStr(j['invoice_number']),
      status: asStr(j['status']),
      customerId: asStr(customer['id']),
      customerName: asStr(customer['name']),
      subtotal: asDouble(j['subtotal']),
      gstTotal: asDouble(j['gst_total']),
      total: asDouble(j['total']),
      issueDate: asDate(j['issue_date']),
      dueDate: asDate(j['due_date']),
      notes: asStr(j['notes']),
      paidAt: asDate(j['paid_at']),
      lines: asMaps(j['items']).map(InvoiceLine.fromJson).toList(),
    );
  }

  final String id;
  final String number;
  final String status;
  final String customerId;
  final String customerName;
  final double subtotal;
  final double gstTotal;
  final double total;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String notes;
  final DateTime? paidAt;
  final List<InvoiceLine> lines;

  bool get isDraft => status == 'DRAFT';
  bool get isPaid => status == 'PAID';
}

/// The business details printed on invoices: GET and PUT /invoicing/profile.
class InvoiceProfile {
  const InvoiceProfile({
    this.companyName = '',
    this.businessType = '',
    this.phone = '',
    this.email = '',
    this.gstin = '',
    this.address = '',
    this.state = '',
    this.bankName = '',
    this.bankAccount = '',
    this.ifsc = '',
    this.invoicePrefix = 'INV',
    this.nextNumber = 1,
    this.defaultGst = 18,
    this.currency = 'INR',
    this.roundTotal = false,
    this.logo = '',
  });

  factory InvoiceProfile.fromJson(Map<String, dynamic> j) => InvoiceProfile(
    companyName: asStr(j['company_name']),
    businessType: asStr(j['business_type']),
    phone: asStr(j['phone']),
    email: asStr(j['email']),
    gstin: asStr(j['gstin']),
    address: asStr(j['address']),
    state: asStr(j['state']),
    bankName: asStr(j['bank_name']),
    bankAccount: asStr(j['bank_account']),
    ifsc: asStr(j['ifsc']),
    invoicePrefix: asStr(j['invoice_prefix']).isEmpty
        ? 'INV'
        : asStr(j['invoice_prefix']),
    nextNumber: j['next_invoice_number'] == null
        ? 1
        : asInt(j['next_invoice_number']),
    defaultGst: j['default_gst'] == null ? 18 : asDouble(j['default_gst']),
    currency: asStr(j['currency']).isEmpty ? 'INR' : asStr(j['currency']),
    roundTotal: j['round_total'] == true || j['round_total'] == 1,
    logo: asStr(j['logo']),
  );

  final String companyName;
  final String businessType;
  final String phone;
  final String email;
  final String gstin;
  final String address;
  final String state;
  final String bankName;
  final String bankAccount;
  final String ifsc;
  final String invoicePrefix;

  /// The number the next invoice will get (after the prefix).
  final int nextNumber;

  /// The GST % used for a line that does not set its own.
  final double defaultGst;
  final String currency;

  /// Whether invoice totals are rounded to a whole amount.
  final bool roundTotal;

  /// The logo as a `data:image` address, or empty. It is changed on the web.
  final String logo;

  /// What PUT /invoicing/profile takes. The logo is left out, so the saved one
  /// stays as it is.
  Map<String, dynamic> toJson() => {
    'company_name': companyName,
    'business_type': businessType,
    'phone': phone,
    'email': email,
    'gstin': gstin,
    'address': address,
    'state': state,
    'bank_name': bankName,
    'bank_account': bankAccount,
    'ifsc': ifsc,
    'invoice_prefix': invoicePrefix,
    'default_gst': defaultGst,
    'currency': currency,
    'round_total': roundTotal,
  };
}

/// The number on the next invoice, such as `INV-0007`.
String nextInvoiceNumber(String prefix, int next) =>
    '$prefix-${next.toString().padLeft(4, '0')}';

/// An invoice and the business profile it was read with.
class InvoiceWithProfile {
  const InvoiceWithProfile({required this.invoice, required this.profile});

  factory InvoiceWithProfile.fromJson(Map<String, dynamic> j) =>
      InvoiceWithProfile(
        invoice: InvoiceDetail.fromJson(asMap(j['invoice'])),
        profile: InvoiceProfile.fromJson(asMap(j['profile'])),
      );

  final InvoiceDetail invoice;
  final InvoiceProfile profile;
}

/// A person you invoice: GET /invoicing/customers.
class InvoiceCustomer {
  const InvoiceCustomer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.gstin = '',
    this.billingAddress = '',
    this.invoicesCount = 0,
  });

  factory InvoiceCustomer.fromJson(Map<String, dynamic> j) => InvoiceCustomer(
    id: asStr(j['id']),
    name: asStr(j['name']),
    email: asStr(j['email']),
    phone: asStr(j['phone']),
    gstin: asStr(j['gstin']),
    billingAddress: asStr(j['billing_address']),
    invoicesCount: asInt(j['invoices_count']),
  );

  final String id;
  final String name;
  final String email;
  final String phone;
  final String gstin;
  final String billingAddress;
  final int invoicesCount;
}

/// Something you sell, with its usual price: GET /invoicing/services.
class InvoiceServiceItem {
  const InvoiceServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.gstPercent,
    this.category = '',
    this.categoryId = '',
    this.active = true,
  });

  factory InvoiceServiceItem.fromJson(Map<String, dynamic> j) =>
      InvoiceServiceItem(
        id: asStr(j['id']),
        name: asStr(j['name']),
        price: asDouble(j['price']),
        gstPercent: asDouble(j['gst_percent']),
        category: asStr(j['category']),
        categoryId: asStr(j['category_id']),
        active: asStr(j['status']).toUpperCase() != 'INACTIVE',
      );

  final String id;
  final String name;
  final double price;
  final double gstPercent;
  final String category;
  final String categoryId;
  final bool active;
}

/// A group of services: GET /invoicing/categories.
class InvoiceCategory {
  const InvoiceCategory({
    required this.id,
    required this.name,
    this.servicesCount = 0,
  });

  factory InvoiceCategory.fromJson(Map<String, dynamic> j) => InvoiceCategory(
    id: asStr(j['id']),
    name: asStr(j['name']),
    servicesCount: asInt(j['services_count']),
  );

  final String id;
  final String name;
  final int servicesCount;
}

/// A line being typed on a new invoice (before the server prices it).
class DraftLine {
  const DraftLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.gstPercent,
    this.serviceId,
  });

  final String description;
  final double quantity;
  final double unitPrice;

  /// Null means "use the business's default GST".
  final double? gstPercent;
  final String? serviceId;

  Map<String, dynamic> toJson() => {
    'description': description,
    if (serviceId != null) 'service_id': serviceId,
    'quantity': quantity,
    'unit_price': unitPrice,
    if (gstPercent != null) 'gst_percent': gstPercent,
  };
}

/// Subtotal, GST and total of lines, worked out the way the server does it
/// (GST per line, rounded to 2 places), so the preview matches what is saved.
({double subtotal, double gst, double total}) invoiceTotals(
  List<DraftLine> lines,
  double defaultGst,
) {
  var subtotal = 0.0;
  var gst = 0.0;
  for (final l in lines) {
    final base = l.quantity * l.unitPrice;
    final pct = l.gstPercent ?? defaultGst;
    subtotal += base;
    gst += (base * pct / 100 * 100).round() / 100;
  }
  subtotal = (subtotal * 100).round() / 100;
  gst = (gst * 100).round() / 100;
  return (
    subtotal: subtotal,
    gst: gst,
    total: ((subtotal + gst) * 100).round() / 100,
  );
}

/// How an expense was paid, as the server writes it.
const expenseMethods = ['CASH', 'BANK', 'UPI', 'CARD', 'OTHER'];

/// One expense: GET /invoicing/expenses.
class InvoiceExpenseRow {
  const InvoiceExpenseRow({
    required this.id,
    required this.description,
    required this.method,
    required this.amount,
    this.date,
    this.category = '',
  });

  factory InvoiceExpenseRow.fromJson(Map<String, dynamic> j) =>
      InvoiceExpenseRow(
        id: asStr(j['id']),
        description: asStr(j['description']),
        method: asStr(j['method']),
        amount: asDouble(j['amount']),
        date: asDate(j['date']),
        category: asStr(j['category']),
      );

  final String id;
  final String description;
  final String method;
  final double amount;
  final DateTime? date;
  final String category;
}

/// GET /invoicing/expenses: the rows, and what was spent this calendar month.
class ExpenseList {
  const ExpenseList({required this.rows, this.spentThisMonth = 0});

  factory ExpenseList.fromJson(Map<String, dynamic> j) => ExpenseList(
    rows: asMaps(j['expenses']).map(InvoiceExpenseRow.fromJson).toList(),
    spentThisMonth: asDouble(asMap(j['stats'])['spent_this_month']),
  );

  final List<InvoiceExpenseRow> rows;

  /// Always the current calendar month, whatever month the list shows.
  final double spentThisMonth;
}
