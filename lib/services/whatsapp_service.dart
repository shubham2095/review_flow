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
          body: {
            'type': 'template',
            'template': t.name,
            'language': t.language,
          },
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
    return _items(
      res['templates'],
    ).map(WaTemplate.fromJson).where((t) => t.approved).toList();
  }

  // ---- Contacts ----

  static Future<WaContactPage> contacts({
    String search = '',
    bool hot = false,
    bool blocked = false,
    bool optedOut = false,
    int page = 1,
  }) async {
    final q = <String, String>{
      'page': '$page',
      'per_page': '25',
      if (search.isNotEmpty) 'search': search,
      if (hot) 'hot': '1',
      if (blocked) 'blocked': '1',
      if (optedOut) 'opted_out': '1',
    };
    final res = await _api.get('/contacts?${Uri(queryParameters: q).query}');
    final meta = asMap(res['meta']);
    final cur = asInt(meta['current_page']);
    final last = asInt(meta['last_page']);
    return WaContactPage(
      items: _items(res['contacts']).map(WaContactRecord.fromJson).toList(),
      page: cur == 0 ? page : cur,
      lastPage: last == 0 ? 1 : last,
      total: asInt(meta['total']),
    );
  }

  static Future<WaContactRecord> createContact({
    required String phone,
    String name = '',
    String email = '',
    String company = '',
    String tags = '',
  }) async {
    final res = await _api.post(
      '/contacts',
      body: {
        'phone': phone,
        if (name.isNotEmpty) 'name': name,
        if (email.isNotEmpty) 'email': email,
        if (company.isNotEmpty) 'company': company,
        if (tags.isNotEmpty) 'tag_list': tags,
      },
    );
    return WaContactRecord.fromJson(asMap(res['contact']));
  }

  /// The server ignores empty name, email and company (it cannot clear them);
  /// an empty [tags] does clear the tags.
  static Future<WaContactRecord> updateContact(
    String id, {
    String? name,
    String? email,
    String? company,
    String? tags,
    bool? blocked,
    bool? optedOut,
  }) async {
    final res = await _api.put(
      '/contacts/$id',
      body: {
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (company != null && company.isNotEmpty) 'company': company,
        'tag_list': ?tags,
        'is_blocked': ?blocked,
        'opted_out': ?optedOut,
      },
    );
    return WaContactRecord.fromJson(asMap(res['contact']));
  }

  static Future<void> deleteContact(String id) async {
    await _api.delete('/contacts/$id');
  }

  // ---- Blacklist ----

  static Future<List<WaBlacklistEntry>> blacklist({String search = ''}) async {
    final q = <String, String>{
      'per_page': '100',
      if (search.isNotEmpty) 'search': search,
    };
    final res = await _api.get('/blacklist?${Uri(queryParameters: q).query}');
    return _items(res['entries']).map(WaBlacklistEntry.fromJson).toList();
  }

  static Future<WaBlacklistEntry> addToBlacklist(
    String phone, {
    String name = '',
    String reason = '',
  }) async {
    final res = await _api.post(
      '/blacklist',
      body: {
        'phone': phone,
        if (name.isNotEmpty) 'name': name,
        if (reason.isNotEmpty) 'reason': reason,
      },
    );
    return WaBlacklistEntry.fromJson(asMap(res['entry']));
  }

  static Future<void> removeFromBlacklist(String id) async {
    await _api.delete('/blacklist/$id');
  }

  // ---- Templates ----

  /// [status] is a server value such as `approved`, `pending` or `rejected`.
  static Future<WaTemplatePage> templates({
    String search = '',
    String? status,
    int page = 1,
  }) async {
    final q = <String, String>{
      'page': '$page',
      'per_page': '30',
      if (search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final res = await _api.get('/templates?${Uri(queryParameters: q).query}');
    final meta = asMap(res['meta']);
    final cur = asInt(meta['current_page']);
    final last = asInt(meta['last_page']);
    return WaTemplatePage(
      items: _items(res['templates']).map(WaTemplate.fromJson).toList(),
      page: cur == 0 ? page : cur,
      lastPage: last == 0 ? 1 : last,
    );
  }

  /// Pulls template statuses from Meta. Returns the server message.
  static Future<String> syncTemplates() async =>
      _msg(await _api.post('/templates/sync'), 'Templates are up to date.');

  static Future<void> deleteTemplate(String id) async {
    await _api.delete('/templates/$id');
  }

  /// Uploads the sample file a media header needs (5 MB, jpg, png, mp4 or
  /// pdf). Returns the `header_handle` to pass to [createTemplate].
  static Future<String> uploadTemplateSample(
    List<int> bytes,
    String filename,
  ) async {
    final res = await _api.upload(
      '/templates/upload-sample',
      field: 'file',
      bytes: bytes,
      filename: filename,
    );
    return asStr(res['header_handle']);
  }

  /// Submits a new template to Meta for approval. Returns the server message.
  static Future<String> createTemplate({
    required String name,
    required String language,
    required String category,
    required String body,
    String headerFormat = 'NONE',
    String headerText = '',
    String headerHandle = '',
    List<String> bodyExamples = const [],
    String footer = '',
    List<WaTemplateButton> buttons = const [],
  }) async {
    final res = await _api.post(
      '/templates',
      body: {
        'name': name,
        'language': language,
        'category': category,
        'body': body,
        'header_format': headerFormat,
        if (headerFormat == 'TEXT') 'header_text': headerText,
        if (headerHandle.isNotEmpty) 'header_handle': headerHandle,
        if (bodyExamples.isNotEmpty) 'body_example': bodyExamples,
        if (footer.isNotEmpty) 'footer': footer,
        if (buttons.isNotEmpty)
          'buttons': [
            for (final b in buttons)
              {
                'type': b.type,
                'text': b.text,
                if (b.type == 'URL') 'url': b.url,
                if (b.type == 'PHONE_NUMBER') 'phone_number': b.phone,
              },
          ],
      },
    );
    return _msg(res, 'Template submitted for approval.');
  }

  // ---- Campaigns ----

  static Future<WaCampaignPage> campaigns({int page = 1}) async {
    final res = await _api.get('/campaigns?page=$page&per_page=20');
    final meta = asMap(res['meta']);
    final cur = asInt(meta['current_page']);
    final last = asInt(meta['last_page']);
    return WaCampaignPage(
      items: _items(res['campaigns']).map(WaCampaign.fromJson).toList(),
      page: cur == 0 ? page : cur,
      lastPage: last == 0 ? 1 : last,
    );
  }

  static Future<WaCampaignDetail> campaign(String id) async {
    final res = await _api.get('/campaigns/$id');
    return WaCampaignDetail(
      campaign: WaCampaign.fromJson(asMap(res['campaign'])),
      recipients: _items(
        res['campaign_contacts'],
      ).map(WaCampaignRecipient.fromJson).toList(),
      totalRecipients: asInt(asMap(res['meta'])['total']),
    );
  }

  /// Creates a draft. The audience is every contact that is not blocked or
  /// opted out, optionally only those from one [source].
  static Future<WaCampaign> createCampaign({
    required String name,
    required String templateId,
    String source = '',
    DateTime? scheduledAt,
  }) async {
    final res = await _api.post(
      '/campaigns',
      body: {
        'name': name,
        'template_id': templateId,
        if (source.isNotEmpty) 'audience_filter': {'source': source},
        if (scheduledAt != null)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      },
    );
    return WaCampaign.fromJson(asMap(res['campaign']));
  }

  static Future<WaCampaign> _campaignAction(String id, String action) async =>
      WaCampaign.fromJson(
        asMap((await _api.post('/campaigns/$id/$action'))['campaign']),
      );

  static Future<WaCampaign> startCampaign(String id) =>
      _campaignAction(id, 'start');

  static Future<WaCampaign> pauseCampaign(String id) =>
      _campaignAction(id, 'pause');

  static Future<WaCampaign> cancelCampaign(String id) =>
      _campaignAction(id, 'cancel');

  static Future<void> deleteCampaign(String id) async {
    await _api.delete('/campaigns/$id');
  }

  // ---- Bulk send ----

  static Future<WaBulkPage> bulkSends({int page = 1}) async {
    final res = await _api.get('/bulk-sends?page=$page&per_page=20');
    final meta = asMap(res['meta']);
    final cur = asInt(meta['current_page']);
    final last = asInt(meta['last_page']);
    return WaBulkPage(
      items: _items(res['bulk_sends']).map(WaBulkSend.fromJson).toList(),
      page: cur == 0 ? page : cur,
      lastPage: last == 0 ? 1 : last,
    );
  }

  static Future<WaBulkSend> bulkSend(String id) async => WaBulkSend.fromJson(
    asMap((await _api.get('/bulk-sends/$id'))['bulk_send']),
  );

  /// Uploads a header image, video or PDF (16 MB at most). Returns a media id.
  static Future<String> uploadBulkHeader(
    List<int> bytes,
    String filename,
  ) async {
    final res = await _api.upload(
      '/bulk-send/upload-header',
      field: 'file',
      bytes: bytes,
      filename: filename,
    );
    return asStr(res['media_id']);
  }

  /// Sends [template] to every number. [variables] fill {{1}}, {{2}}… the same
  /// for everyone. Blocked numbers are skipped by the server.
  static Future<WaBulkSend> sendBulk({
    required List<String> numbers,
    required WaTemplate template,
    List<String> variables = const [],
    String headerMediaId = '',
    String headerMediaUrl = '',
  }) async {
    final res = await _api.post(
      '/bulk-send',
      body: {
        'numbers': numbers,
        'template': template.name,
        'language': template.language,
        if (variables.isNotEmpty) 'variables': variables,
        if (headerMediaId.isNotEmpty) 'header_media_id': headerMediaId,
        if (headerMediaUrl.isNotEmpty) 'header_media_url': headerMediaUrl,
      },
      timeout: const Duration(seconds: 60),
    );
    return WaBulkSend.fromJson(asMap(res['bulk_send']));
  }

  static Future<WaBulkSend> retryBulk(String id) async => WaBulkSend.fromJson(
    asMap((await _api.post('/bulk-sends/$id/retry'))['bulk_send']),
  );

  // ---- Chatbots ----

  static Future<WaChatbotPage> chatbots({int page = 1}) async {
    final res = await _api.get('/chatbots?page=$page&per_page=20');
    final meta = asMap(res['meta']);
    final cur = asInt(meta['current_page']);
    final last = asInt(meta['last_page']);
    return WaChatbotPage(
      items: _items(res['chatbots']).map(WaChatbot.fromJson).toList(),
      page: cur == 0 ? page : cur,
      lastPage: last == 0 ? 1 : last,
    );
  }

  static Future<WaChatbot> chatbot(String id) async =>
      WaChatbot.fromJson(asMap((await _api.get('/chatbots/$id'))['chatbot']));

  static Future<WaChatbot> createChatbot({
    required String name,
    String welcome = '',
    String fallback = '',
  }) async => WaChatbot.fromJson(
    asMap(
      (await _api.post(
        '/chatbots',
        body: {
          'name': name,
          if (welcome.isNotEmpty) 'welcome_message': welcome,
          if (fallback.isNotEmpty) 'fallback_message': fallback,
        },
      ))['chatbot'],
    ),
  );

  /// Sends only the fields given. Empty text is sent as empty to clear it.
  static Future<WaChatbot> updateChatbot(
    String id, {
    String? name,
    String? welcome,
    String? fallback,
    bool? aiEnabled,
    String? aiInstructions,
    bool? followupEnabled,
    String? followupMessage,
  }) async => WaChatbot.fromJson(
    asMap(
      (await _api.put(
        '/chatbots/$id',
        body: {
          'name': ?name,
          'welcome_message': ?welcome,
          'fallback_message': ?fallback,
          'ai_enabled': ?aiEnabled,
          'ai_instructions': ?aiInstructions,
          'followup_enabled': ?followupEnabled,
          'followup_message': ?followupMessage,
        },
      ))['chatbot'],
    ),
  );

  static Future<WaChatbot> toggleChatbot(String id) async => WaChatbot.fromJson(
    asMap((await _api.post('/chatbots/$id/toggle'))['chatbot']),
  );

  static Future<void> deleteChatbot(String id) async {
    await _api.delete('/chatbots/$id');
  }

  static Map<String, dynamic> _ruleBody({
    String? keyword,
    String? matchType,
    String? responseType,
    String? responseText,
    String? templateName,
    int? priority,
    bool? active,
  }) => {
    'keyword': ?keyword,
    'match_type': ?matchType,
    'response_type': ?responseType,
    'response_text': ?responseText,
    'template_name': ?templateName,
    'priority': ?priority,
    'is_active': ?active,
  };

  static Future<WaChatRule> addRule(
    String chatbotId, {
    required String keyword,
    required String matchType,
    required String responseType,
    String responseText = '',
    String templateName = '',
    int priority = 0,
  }) async => WaChatRule.fromJson(
    asMap(
      (await _api.post(
        '/chatbots/$chatbotId/rules',
        body: _ruleBody(
          keyword: keyword,
          matchType: matchType,
          responseType: responseType,
          responseText: responseText,
          templateName: templateName,
          priority: priority,
        ),
      ))['rule'],
    ),
  );

  static Future<WaChatRule> updateRule(
    String chatbotId,
    String ruleId, {
    String? keyword,
    String? matchType,
    String? responseType,
    String? responseText,
    String? templateName,
    int? priority,
    bool? active,
  }) async => WaChatRule.fromJson(
    asMap(
      (await _api.put(
        '/chatbots/$chatbotId/rules/$ruleId',
        body: _ruleBody(
          keyword: keyword,
          matchType: matchType,
          responseType: responseType,
          responseText: responseText,
          templateName: templateName,
          priority: priority,
          active: active,
        ),
      ))['rule'],
    ),
  );

  static Future<void> deleteRule(String chatbotId, String ruleId) async {
    await _api.delete('/chatbots/$chatbotId/rules/$ruleId');
  }

  static Future<WaLeadFlow> leadFlow() async =>
      WaLeadFlow.fromJson(await _api.get('/chatbots/lead-flow'));

  static Future<String> installLeadFlow() async => _msg(
    await _api.post('/chatbots/lead-flow/install'),
    'Lead automation installed.',
  );

  // ---- Automations (workflows) ----

  static Future<WaWorkflowPage> workflows({int page = 1}) async {
    final res = await _api.get('/automations?page=$page&per_page=20');
    final meta = asMap(res['meta']);
    final cur = asInt(meta['current_page']);
    final last = asInt(meta['last_page']);
    return WaWorkflowPage(
      items: _items(res['workflows']).map(WaWorkflow.fromJson).toList(),
      page: cur == 0 ? page : cur,
      lastPage: last == 0 ? 1 : last,
    );
  }

  static Future<WaWorkflow> workflow(String id) async => WaWorkflow.fromJson(
    asMap((await _api.get('/automations/$id'))['workflow']),
  );

  static Future<WaExecutionPage> executions(String id, {int page = 1}) async {
    final res = await _api.get(
      '/automations/$id/executions?page=$page&per_page=25',
    );
    final meta = asMap(res['meta']);
    final cur = asInt(meta['current_page']);
    final last = asInt(meta['last_page']);
    return WaExecutionPage(
      items: _items(res['executions']).map(WaExecution.fromJson).toList(),
      page: cur == 0 ? page : cur,
      lastPage: last == 0 ? 1 : last,
    );
  }

  static Future<WaWorkflow> activateWorkflow(String id) async =>
      WaWorkflow.fromJson(
        asMap((await _api.post('/automations/$id/activate'))['workflow']),
      );

  static Future<WaWorkflow> pauseWorkflow(String id) async =>
      WaWorkflow.fromJson(
        asMap((await _api.post('/automations/$id/pause'))['workflow']),
      );

  static Future<void> deleteWorkflow(String id) async {
    await _api.delete('/automations/$id');
  }

  // ---- Analytics ----

  static Future<WaDashboard> analyticsDashboard() async =>
      WaDashboard.fromJson(await _api.get('/analytics/dashboard'));

  /// The message funnel for the last [days] days (the server caps it at 90).
  static Future<WaMessageStats> messageStats(int days) async =>
      WaMessageStats.fromJson(
        await _api.get('/analytics/messages?days=$days'),
        days,
      );

  static Future<List<WaCampaignStat>> campaignStats() async {
    final res = await _api.get('/analytics/campaigns');
    return _items(res['campaigns']).map(WaCampaignStat.fromJson).toList();
  }
}
