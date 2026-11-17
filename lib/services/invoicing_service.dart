import '../models/gbp_models.dart' show asMap, asMaps, asStr;
import '../models/invoicing_models.dart';
import 'api_service.dart';

/// Customer invoicing (/api/v1/invoicing/...). Needs the `invoicing` plan
/// feature.
class InvoicingService {
  InvoicingService._();

  static final _api = ApiService.instance;

  // ---- Invoices ----

  /// The invoices (newest first) and the totals. [query] searches the number
  /// and the customer's name on the server.
  static Future<InvoiceList> invoices({String query = ''}) async {
    final q = query.trim();
    final path = q.isEmpty
        ? '/invoicing/invoices'
        : '/invoicing/invoices?q=${Uri.encodeQueryComponent(q)}';
    return InvoiceList.fromJson(await _api.get(path));
  }

  static Future<InvoiceWithProfile> invoice(String id) async =>
      InvoiceWithProfile.fromJson(await _api.get('/invoicing/invoices/$id'));

  /// Saves a new invoice as a draft; the server numbers it and prices it.
  static Future<InvoiceDetail> createInvoice({
    required String customerId,
    required DateTime issueDate,
    DateTime? dueDate,
    String notes = '',
    required List<DraftLine> lines,
  }) async {
    final res = await _api.post(
      '/invoicing/invoices',
      body: {
        'customer_id': customerId,
        'issue_date': apiDate(issueDate),
        if (dueDate != null) 'due_date': apiDate(dueDate),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        'items': [for (final l in lines) l.toJson()],
      },
    );
    return InvoiceDetail.fromJson(asMap(res['invoice']));
  }

  static Future<String> markSent(String id) async => _message(
    await _api.post('/invoicing/invoices/$id/sent'),
    'Invoice marked as sent.',
  );

  static Future<String> markPaid(String id) async => _message(
    await _api.post('/invoicing/invoices/$id/paid'),
    'Invoice marked as paid.',
  );

  /// Only a draft can be deleted; the server refuses the rest.
  static Future<String> deleteInvoice(String id) async => _message(
    await _api.delete('/invoicing/invoices/$id'),
    'Invoice deleted.',
  );

  // ---- Customers and services (the invoice form needs these) ----

  static Future<List<InvoiceCustomer>> customers() async {
    final res = await _api.get('/invoicing/customers');
    return asMaps(res['customers']).map(InvoiceCustomer.fromJson).toList();
  }

  /// Adds a customer and returns its id and name.
  static Future<InvoiceCustomer> addCustomer({
    required String name,
    String phone = '',
    String email = '',
    String gstin = '',
    String billingAddress = '',
  }) async {
    final res = await _api.post(
      '/invoicing/customers',
      body: {
        'name': name,
        if (phone.isNotEmpty) 'phone': phone,
        if (email.isNotEmpty) 'email': email,
        if (gstin.isNotEmpty) 'gstin': gstin,
        if (billingAddress.isNotEmpty) 'billing_address': billingAddress,
      },
    );
    return InvoiceCustomer.fromJson(asMap(res['customer']));
  }

  /// Saves a customer. The server replaces every field, so all of them are
  /// sent (an empty one clears it).
  static Future<void> updateCustomer(
    String id, {
    required String name,
    String phone = '',
    String email = '',
    String gstin = '',
    String billingAddress = '',
  }) async {
    await _api.put(
      '/invoicing/customers/$id',
      body: {
        'name': name,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'billing_address': billingAddress,
      },
    );
  }

  static Future<String> deleteCustomer(String id) async => _message(
    await _api.delete('/invoicing/customers/$id'),
    'Customer deleted.',
  );

  static Future<List<InvoiceServiceItem>> services() async {
    final res = await _api.get('/invoicing/services');
    return asMaps(res['services']).map(InvoiceServiceItem.fromJson).toList();
  }

  static Future<void> addService({
    required String name,
    required double price,
    required double gstPercent,
    String? categoryId,
  }) async {
    await _api.post(
      '/invoicing/services',
      body: {
        'name': name,
        'price': price,
        'gst_percent': gstPercent,
        'category_id': ?categoryId,
      },
    );
  }

  /// Saves a service. The server clears the category when none is sent, so
  /// pass the current one again to keep it.
  static Future<void> updateService(
    String id, {
    required String name,
    required double price,
    required double gstPercent,
    String? categoryId,
    required bool active,
  }) async {
    await _api.put(
      '/invoicing/services/$id',
      body: {
        'name': name,
        'price': price,
        'gst_percent': gstPercent,
        'category_id': ?categoryId,
        'status': active ? 'ACTIVE' : 'INACTIVE',
      },
    );
  }

  static Future<String> deleteService(String id) async => _message(
    await _api.delete('/invoicing/services/$id'),
    'Service deleted.',
  );

  static Future<List<InvoiceCategory>> categories() async {
    final res = await _api.get('/invoicing/categories');
    return asMaps(res['categories']).map(InvoiceCategory.fromJson).toList();
  }

  static Future<void> addCategory(String name) async {
    await _api.post('/invoicing/categories', body: {'name': name});
  }

  static Future<String> deleteCategory(String id) async => _message(
    await _api.delete('/invoicing/categories/$id'),
    'Category deleted.',
  );

  /// The business details: GST default, currency and invoice prefix.
  static Future<InvoiceProfile> profile() async => InvoiceProfile.fromJson(
    asMap((await _api.get('/invoicing/profile'))['profile']),
  );

  static String _message(Map<String, dynamic> res, String fallback) {
    final m = asStr(res['message']);
    return m.isEmpty ? fallback : m;
  }
}

/// A date as the server wants it: `2026-11-17`.
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
