import '../models/gbp_models.dart';
import '../models/whatsapp_models.dart';
import 'api_service.dart';

/// WhatsApp calls (/api/v1/whatsapp/...). Later phases add inbox, contacts,
/// templates and campaigns here.
class WhatsAppService {
  WhatsAppService._();

  static final _api = ApiService.instance;

  /// Free home summary: numbers plus inbox and message counts.
  static Future<WaOverview> overview() async =>
      WaOverview.fromJson(await _api.get('/whatsapp/overview'));

  static Future<List<WaNumber>> numbers() async {
    final res = await _api.get('/whatsapp/numbers');
    return asMaps(res['numbers']).map(WaNumber.fromJson).toList();
  }

  static String _msg(Map<String, dynamic> res, String fallback) {
    final m = asStr(res['message']);
    return m.isEmpty ? fallback : m;
  }

  /// Connects a number by hand (the mobile-friendly path).
  static Future<WaNumber> connectManual({
    required String wabaId,
    required String phoneNumberId,
    required String displayNumber,
    required String accessToken,
    String name = '',
    String verifiedName = '',
  }) async {
    final res = await _api.post(
      '/whatsapp/connect-manual',
      body: {
        'waba_id': wabaId,
        'phone_number_id': phoneNumberId,
        'display_phone_number': displayNumber,
        'access_token': accessToken,
        if (name.isNotEmpty) 'name': name,
        if (verifiedName.isNotEmpty) 'verified_name': verifiedName,
      },
    );
    return WaNumber.fromJson(asMap(res['number']));
  }

  /// Pulls numbers added on Meta since connecting. Returns the server message.
  static Future<String> refreshNumbers() async =>
      _msg(await _api.post('/whatsapp/numbers/refresh'), 'Numbers refreshed.');

  static Future<WaNumber> sync(String id) async => WaNumber.fromJson(
    asMap((await _api.post('/whatsapp/numbers/$id/sync'))['number']),
  );

  static Future<WaNumber> register(String id, String pin) async =>
      WaNumber.fromJson(
        asMap(
          (await _api.post(
            '/whatsapp/numbers/$id/register',
            body: {'pin': pin},
          ))['number'],
        ),
      );

  static Future<String> subscribeApp(String id) async => _msg(
    await _api.post('/whatsapp/numbers/$id/subscribe-app'),
    'Done. Try sending again.',
  );

  static Future<String> updateToken(String id, String token) async => _msg(
    await _api.put(
      '/whatsapp/numbers/$id/token',
      body: {'access_token': token},
    ),
    'Access token updated.',
  );

  /// Sends the approved `hello_world` template (or [body] as plain text) to [to].
  static Future<void> sendTest(String id, String to, {String? body}) async {
    await _api.post(
      '/whatsapp/numbers/$id/send-test',
      body: {
        'to': to,
        if (body != null && body.isNotEmpty) ...{'type': 'text', 'body': body},
      },
    );
  }

  static Future<String> disconnect(String id) async =>
      _msg(await _api.delete('/whatsapp/numbers/$id'), 'Number disconnected.');
}
