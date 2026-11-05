import '../models/account_models.dart';
import '../models/admin_models.dart';
import '../models/gbp_models.dart';
import 'api_service.dart';

/// Super admin calls (/admin/* and the admin support list).
class AdminService {
  AdminService._();

  static final _api = ApiService.instance;

  // ---- Companies ----

  static Future<({List<AdminCompany> companies, List<AdminPlanOption> plans})>
      companies() async {
    final res = await _api.get('/admin/companies');
    return (
      companies: asMaps(res['companies']).map(AdminCompany.fromJson).toList(),
      plans: asMaps(res['plans'])
          .map((p) => AdminPlanOption(asStr(p['id']), asStr(p['name'])))
          .toList(),
    );
  }

  static Future<void> createCompany(Map<String, dynamic> body) async {
    await _api.post('/admin/companies', body: body);
  }

  static Future<void> updateCompany(String id, Map<String, dynamic> body) async {
    await _api.put('/admin/companies/$id', body: body);
  }

  /// Suspends or reactivates. Returns the new status.
  static Future<String> toggleCompany(String id) async {
    final res = await _api.post('/admin/companies/$id/toggle');
    return asStr(res['status']);
  }

  static Future<void> assignPlan(String id, String planId) async {
    await _api.post('/admin/companies/$id/plan', body: {'plan_id': planId});
  }

  static Future<int> addCredits(String id, int amount) async {
    final res = await _api.post(
      '/admin/companies/$id/credits',
      body: {'amount': amount},
    );
    return asInt(res['balance']);
  }

  static Future<List<AdminUser>> companyUsers(String id) async {
    final res = await _api.get('/admin/companies/$id/users');
    return asMaps(res['users']).map(AdminUser.fromJson).toList();
  }

  static Future<String> resetUserPassword(
    String companyId,
    String userId,
    String password,
  ) async {
    final res = await _api.post(
      '/admin/companies/$companyId/users/$userId/reset-password',
      body: {'password': password},
    );
    return asStr(res['message']);
  }

  static Future<void> deleteCompany(String id) async {
    await _api.delete('/admin/companies/$id');
  }

  // ---- Plans ----

  static Future<AdminPlansData> plans() async {
    final res = await _api.get('/admin/plans');
    List<String> keys(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];
    return AdminPlansData(
      asMaps(res['plans']).map(AdminPlan.fromJson).toList(),
      keys(res['limit_keys']),
      keys(res['feature_keys']),
    );
  }

  static Future<void> savePlan(String? id, Map<String, dynamic> body) async {
    if (id == null) {
      await _api.post('/admin/plans', body: body);
    } else {
      await _api.put('/admin/plans/$id', body: body);
    }
  }

  static Future<void> togglePlan(String id) async {
    await _api.post('/admin/plans/$id/toggle');
  }

  static Future<void> deletePlan(String id) async {
    await _api.delete('/admin/plans/$id');
  }

  // ---- Credit packs ----

  static Future<List<AdminCreditPack>> packs() async {
    final res = await _api.get('/admin/credit-packs');
    return asMaps(res['packs']).map(AdminCreditPack.fromJson).toList();
  }

  static Future<void> savePack(String? id, Map<String, dynamic> body) async {
    if (id == null) {
      await _api.post('/admin/credit-packs', body: body);
    } else {
      await _api.put('/admin/credit-packs/$id', body: body);
    }
  }

  static Future<void> togglePack(String id) async {
    await _api.post('/admin/credit-packs/$id/toggle');
  }

  static Future<void> deletePack(String id) async {
    await _api.delete('/admin/credit-packs/$id');
  }

  // ---- Payments ----

  static Future<AdminPaymentsData> payments() async {
    final res = await _api.get('/admin/payments');
    final stats = asMap(res['stats']);
    return AdminPaymentsData(
      payments: asMaps(res['payments']).map(AdminPayment.fromJson).toList(),
      count: asInt(stats['count']),
      paid: asInt(stats['paid']),
      revenue: asStr(stats['revenue']),
    );
  }

  // ---- Settings ----

  static Future<InvoiceSettings> invoiceSettings() async {
    final res = await _api.get('/admin/settings');
    return InvoiceSettings.fromJson(asMap(res['settings']));
  }

  static Future<InvoiceSettings> saveInvoiceSettings(
    Map<String, dynamic> body,
  ) async {
    final res = await _api.put('/admin/settings', body: body);
    return InvoiceSettings.fromJson(asMap(res['settings']));
  }

  static Future<AiSettingsData> aiSettings() async {
    final res = await _api.get('/admin/ai-settings');
    return AiSettingsData.fromJson(asMap(res['ai']));
  }

  static Future<AiSettingsData> saveAiSettings(Map<String, dynamic> body) async {
    final res = await _api.put('/admin/ai-settings', body: body);
    return AiSettingsData.fromJson(asMap(res['ai']));
  }

  static Future<AiTestResult> testAiProvider(String provider) async {
    final res = await _api.post(
      '/admin/ai-settings/test',
      body: {'provider': provider},
      timeout: kAiTimeout,
    );
    final r = asMap(res['result']);
    final ok = r['ok'] == true;
    return AiTestResult(
      ok: ok,
      message: ok
          ? 'Working. Model ${asStr(r['model'])} replied: ${asStr(r['sample'])}'
          : asStr(r['message']),
    );
  }

  // ---- Support (all companies) ----

  static Future<List<SupportTicket>> tickets({String? status}) async {
    final res = await _api.get(
      '/support/admin/all${status == null ? '' : '?status=$status'}',
    );
    return asMaps(res['tickets']).map(SupportTicket.fromJson).toList();
  }

  static Future<SupportTicket> replyToTicket(
    String id, {
    required String reply,
    required String status,
  }) async {
    final res = await _api.put(
      '/support/$id/reply',
      body: {'admin_reply': reply, 'status': status},
    );
    return SupportTicket.fromJson(asMap(res['ticket']));
  }
}
