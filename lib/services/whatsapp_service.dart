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

  // ---- Inbox ----

  /// A list the server may send bare or wrapped in `data`.
  static List<Map<String, dynamic>> _items(dynamic v) {
    if (v is Map<String, dynamic>) return asMaps(v['data']);
    return asMaps(v);
  }

  /// Hot leads first, then newest. [status] is a server value such as `open`.
  static Future<WaConversationPage> conversations({
    String search = '',
    String? status,
    int page = 1,
  }) async {
    final q = <String, String>{
      'page': '$page',
      'per_page': '25',
      if (search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final res = await _api.get(
      '/whatsapp/conversations?${Uri(queryParameters: q).query}',
    );
    final meta = asMap(res['meta']);
    return WaConversationPage(
      items: _items(res['conversations']).map(WaConversation.fromJson).toList(),
      page: asInt(meta['current_page']) == 0
          ? page
          : asInt(meta['current_page']),
      lastPage: asInt(meta['last_page']) == 0 ? 1 : asInt(meta['last_page']),
    );
  }

  /// One page of messages, newest first. Pass [cursor] for older ones.
  static Future<WaMessagePage> messages(String id, {String? cursor}) async {
    final q = <String, String>{
      'per_page': '40',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final res = await _api.get(
      '/whatsapp/conversations/$id/messages?${Uri(queryParameters: q).query}',
    );
    final next = asStr(res['next_cursor']);
    return WaMessagePage(
      items: _items(res['messages']).map(WaMessage.fromJson).toList(),
      hasMore: res['has_more'] == true,
      nextCursor: next.isEmpty ? null : next,
    );
  }

  static Future<void> markRead(String id) async {
    await _api.post('/whatsapp/conversations/$id/mark-read');
  }

  // ---- Replies ----

  static WaMessage _message(Map<String, dynamic> res) =>
      WaMessage.fromJson(asMap(res['message']));

  /// Plain text. The server refuses (422) once the 24-hour window has closed.
  static Future<WaMessage> sendText(String id, String body) async => _message(
    await _api.post(
      '/whatsapp/conversations/$id/send',
      body: {'type': 'text', 'body': body},
    ),
  );

  /// An approved template by name and language (no variables).
  static Future<WaMessage> sendTemplate(String id, WaTemplate t) async =>
      _message(
        await _api.post(
          '/whatsapp/conversations/$id/send',
          body: {'type': 'template', 'template': t.name, 'language': t.language},
        ),
      );

  /// [mediaType] is image, video, audio or document (16 MB at most).
  static Future<WaMessage> sendMedia(
    String id, {
    required List<int> bytes,
    required String filename,
    required String mediaType,
    String caption = '',
  }) async => _message(
    await _api.upload(
      '/whatsapp/conversations/$id/send-media',
      field: 'file',
      bytes: bytes,
      filename: filename,
      fields: {
        'media_type': mediaType,
        if (caption.isNotEmpty) 'caption': caption,
      },
    ),
  );

  /// Removes the message from Eydia only: it stays on the customer's phone.
  static Future<void> deleteMessage(String id, String messageId) async {
    await _api.delete('/whatsapp/conversations/$id/messages/$messageId');
  }

  /// Approved templates, for replying after the 24-hour window.
  static Future<List<WaTemplate>> approvedTemplates() async {
    final res = await _api.get('/templates?status=approved&per_page=50');
    return _items(res['templates'])
        .map(WaTemplate.fromJson)
        .where((t) => t.approved)
        .toList();
  }
}
