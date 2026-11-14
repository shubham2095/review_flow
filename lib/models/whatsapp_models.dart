import 'dart:convert';

import 'gbp_models.dart';

/// One connected WhatsApp number (GET /whatsapp/numbers, /overview).
class WaNumber {
  WaNumber({
    required this.id,
    required this.phoneNumberId,
    required this.displayNumber,
    required this.verifiedName,
    required this.quality,
    required this.status,
    required this.isDefault,
    required this.isRegistered,
    this.wabaName = '',
    this.createdAt,
  });

  factory WaNumber.fromJson(Map<String, dynamic> j) {
    final waba = asMap(j['waba']);
    return WaNumber(
      id: asStr(j['id']),
      phoneNumberId: asStr(j['phone_number_id']),
      displayNumber: asStr(j['display_phone_number']),
      verifiedName: asStr(j['verified_name']),
      quality: asStr(j['quality_rating']),
      status: asStr(j['status']),
      isDefault: j['is_default'] == true,
      isRegistered: j['is_registered'] == true,
      wabaName: asStr(waba['name']),
      createdAt: asDate(j['created_at']),
    );
  }

  /// The number's UUID, used in every /numbers/{id} call.
  final String id;
  final String phoneNumberId;
  final String displayNumber;
  final String verifiedName;

  /// GREEN, YELLOW or RED from Meta; empty when unknown.
  final String quality;
  final String status;
  final bool isDefault;
  final bool isRegistered;
  final String wabaName;
  final DateTime? createdAt;
}

class WaConversationCounts {
  const WaConversationCounts({this.total = 0, this.open = 0, this.unread = 0});

  factory WaConversationCounts.fromJson(Map<String, dynamic> j) =>
      WaConversationCounts(
        total: asInt(j['total']),
        open: asInt(j['open']),
        unread: asInt(j['unread']),
      );

  final int total;
  final int open;
  final int unread;
}

/// GET /whatsapp/overview: the free home summary.
class WaOverview {
  WaOverview({
    required this.numbers,
    required this.conversations,
    required this.inboundToday,
    required this.outboundToday,
  });

  factory WaOverview.fromJson(Map<String, dynamic> j) {
    final today = asMap(j['messages_today']);
    return WaOverview(
      numbers: asMaps(j['numbers']).map(WaNumber.fromJson).toList(),
      conversations: WaConversationCounts.fromJson(asMap(j['conversations'])),
      inboundToday: asInt(today['inbound']),
      outboundToday: asInt(today['outbound']),
    );
  }

  final List<WaNumber> numbers;
  final WaConversationCounts conversations;
  final int inboundToday;
  final int outboundToday;

  bool get hasNumbers => numbers.isNotEmpty;
}

/// The person on the other side of a chat.
class WaContact {
  const WaContact({
    this.id = '',
    this.name = '',
    this.phone = '',
    this.isHot = false,
    this.hotReason = '',
  });

  factory WaContact.fromJson(Map<String, dynamic> j) => WaContact(
    id: asStr(j['id']),
    name: asStr(j['name']),
    phone: asStr(j['phone']).isEmpty ? asStr(j['wa_id']) : asStr(j['phone']),
    isHot: j['is_hot'] == true,
    hotReason: asStr(j['hot_reason']),
  );

  final String id;
  final String name;
  final String phone;
  final bool isHot;
  final String hotReason;

  /// Name when there is one, otherwise the number.
  String get title => name.trim().isNotEmpty
      ? name.trim()
      : (phone.isEmpty ? 'Unknown contact' : phone);
}

class WaConversation {
  WaConversation({
    required this.id,
    required this.status,
    required this.unread,
    required this.contact,
    required this.preview,
    required this.windowOpen,
    this.lastMessageAt,
    this.windowExpiresAt,
    this.numberLabel = '',
    this.agentName = '',
  });

  factory WaConversation.fromJson(Map<String, dynamic> j) {
    final number = asMap(j['phone_number']);
    return WaConversation(
      id: asStr(j['id']),
      status: asStr(j['status']),
      unread: asInt(j['unread_count']),
      contact: WaContact.fromJson(asMap(j['contact'])),
      preview: asStr(j['last_message_preview']),
      windowOpen: j['window_open'] == true,
      lastMessageAt: asDate(j['last_message_at']),
      windowExpiresAt: asDate(j['window_expires_at']),
      numberLabel: asStr(number['display_phone_number']),
      agentName: asStr(asMap(j['assigned_agent'])['name']),
    );
  }

  final String id;
  final String status;
  int unread;
  final WaContact contact;
  final String preview;

  /// Mutable: a new customer message re-opens the 24-hour window.
  bool windowOpen;
  final DateTime? lastMessageAt;
  DateTime? windowExpiresAt;
  final String numberLabel;
  final String agentName;
}

class WaConversationPage {
  const WaConversationPage({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<WaConversation> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

class WaAttachment {
  const WaAttachment({
    required this.type,
    required this.mime,
    required this.fileName,
    required this.size,
    required this.caption,
    required this.url,
  });

  factory WaAttachment.fromJson(Map<String, dynamic> j) => WaAttachment(
    type: asStr(j['type']),
    mime: asStr(j['mime_type']),
    fileName: asStr(j['file_name']),
    size: asInt(j['file_size']),
    caption: asStr(j['caption']),
    url: asStr(j['url']),
  );

  final String type;
  final String mime;
  final String fileName;
  final int size;
  final String caption;

  /// Public media URL (empty when the file was not stored).
  final String url;

  bool get isImage => type == 'image' || mime.startsWith('image/');
}

class WaMessage {
  WaMessage({
    required this.id,
    required this.outbound,
    required this.type,
    required this.body,
    required this.status,
    required this.attachments,
    required this.errorMessage,
    this.senderName = '',
    this.createdAt,
  });

  factory WaMessage.fromJson(Map<String, dynamic> j) => WaMessage(
    id: asStr(j['id']),
    outbound: asStr(j['direction']) == 'outbound',
    type: asStr(j['type']),
    body: asStr(j['body']),
    status: asStr(j['status']),
    attachments: asMaps(j['attachments']).map(WaAttachment.fromJson).toList(),
    errorMessage: asStr(j['error_message']),
    senderName: asStr(asMap(j['sender'])['name']),
    createdAt: asDate(j['created_at']),
  );

  final String id;
  final bool outbound;
  final String type;
  final String body;

  /// sent, delivered, read or failed (outbound), received (inbound).
  final String status;
  final List<WaAttachment> attachments;
  final String errorMessage;
  final String senderName;
  final DateTime? createdAt;

  bool get failed => status == 'failed';
}

class WaMessagePage {
  const WaMessagePage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });

  /// Newest first, as the server sends them.
  final List<WaMessage> items;
  final bool hasMore;
  final String? nextCursor;
}

/// One button on a template.
class WaTemplateButton {
  const WaTemplateButton({
    required this.type,
    required this.text,
    this.url = '',
    this.phone = '',
  });

  factory WaTemplateButton.fromJson(Map<String, dynamic> j) => WaTemplateButton(
    type: asStr(j['type']).toUpperCase(),
    text: asStr(j['text']),
    url: asStr(j['url']),
    phone: asStr(j['phone_number']),
  );

  /// QUICK_REPLY, URL, PHONE_NUMBER or COPY_CODE.
  final String type;
  final String text;
  final String url;
  final String phone;
}

/// A message template (GET /templates). Only name and language can be sent
/// from a chat, so templates with `{{1}}` style fields or a media header are
/// marked as needing input.
class WaTemplate {
  const WaTemplate({
    required this.id,
    required this.name,
    required this.language,
    required this.category,
    required this.status,
    required this.body,
    required this.needsInput,
    this.rejectionReason = '',
    this.quality = '',
    this.lastSyncedAt,
    this.headerFormat = '',
    this.headerText = '',
    this.footer = '',
    this.buttons = const [],
  });

  factory WaTemplate.fromJson(Map<String, dynamic> j) {
    final parts = asMaps(j['components']);
    var body = '';
    var needs = false;
    var headerFormat = '';
    var headerText = '';
    var footer = '';
    final buttons = <WaTemplateButton>[];
    for (final c in parts) {
      final type = asStr(c['type']).toUpperCase();
      final format = asStr(c['format']).toUpperCase();
      final text = asStr(c['text']);
      if (type == 'BODY') body = text;
      if (type == 'FOOTER') footer = text;
      if (type == 'HEADER') {
        headerFormat = format;
        headerText = text;
        if (format.isNotEmpty && format != 'TEXT') needs = true;
      }
      if (text.contains('{{')) needs = true;
      final raw = c['buttons'];
      if (raw != null) {
        if (jsonEncode(raw).contains('{{')) needs = true;
        if (raw is List) {
          buttons.addAll(
            raw.whereType<Map<String, dynamic>>().map(
              WaTemplateButton.fromJson,
            ),
          );
        }
      }
    }
    return WaTemplate(
      id: asStr(j['id']),
      name: asStr(j['name']),
      language: asStr(j['language']),
      category: asStr(j['category']),
      status: asStr(j['status']),
      body: body,
      needsInput: needs,
      rejectionReason: asStr(j['rejection_reason']),
      quality: asStr(j['quality_score']),
      lastSyncedAt: asDate(j['last_synced_at']),
      headerFormat: headerFormat,
      headerText: headerText,
      footer: footer,
      buttons: buttons,
    );
  }

  final String id;
  final String name;
  final String language;
  final String category;
  final String status;
  final String body;

  /// Has fields or a media header that a chat cannot fill in.
  final bool needsInput;
  final String rejectionReason;
  final String quality;
  final DateTime? lastSyncedAt;

  /// TEXT, IMAGE, VIDEO or DOCUMENT; empty when there is no header.
  final String headerFormat;
  final String headerText;
  final String footer;
  final List<WaTemplateButton> buttons;

  bool get approved => status.toUpperCase() == 'APPROVED';

  /// The body fields in order: [1, 2, ...] for {{1}}, {{2}}.
  List<int> get bodyVariables =>
      (RegExp(
          r'{{s*(d+)s*}}',
        ).allMatches(body).map((m) => int.parse(m.group(1)!)).toSet().toList()
        ..sort());

  /// Whether a bulk send can fill this template in: body fields and a media
  /// header are supported, header text fields and link buttons with fields
  /// are not.
  bool get bulkSendable =>
      !headerText.contains('{{') && !buttons.any((b) => b.url.contains('{{'));

  bool get hasMediaHeader => headerFormat.isNotEmpty && headerFormat != 'TEXT';
}

class WaTemplatePage {
  const WaTemplatePage({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<WaTemplate> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

/// A saved contact (GET /contacts). Tags are plain text here ("vip, delhi").
class WaContactRecord {
  const WaContactRecord({
    required this.id,
    required this.phone,
    required this.name,
    required this.email,
    required this.company,
    required this.tagList,
    required this.source,
    required this.isHot,
    required this.hotReason,
    required this.isBlocked,
    required this.optedOut,
    this.lastInteractionAt,
    this.agentName = '',
  });

  factory WaContactRecord.fromJson(Map<String, dynamic> j) => WaContactRecord(
    id: asStr(j['id']),
    phone: asStr(j['phone']).isEmpty ? asStr(j['wa_id']) : asStr(j['phone']),
    name: asStr(j['name']),
    email: asStr(j['email']),
    company: asStr(j['company']),
    tagList: asStr(j['tag_list']),
    source: asStr(j['source']),
    isHot: j['is_hot'] == true,
    hotReason: asStr(j['hot_reason']),
    isBlocked: j['is_blocked'] == true || j['is_blocked'] == 1,
    optedOut: j['opted_out'] == true || j['opted_out'] == 1,
    lastInteractionAt: asDate(j['last_interaction_at']),
    agentName: asStr(asMap(j['assigned_agent'])['name']),
  );

  final String id;
  final String phone;
  final String name;
  final String email;
  final String company;
  final String tagList;
  final String source;
  final bool isHot;
  final String hotReason;
  final bool isBlocked;
  final bool optedOut;
  final DateTime? lastInteractionAt;
  final String agentName;

  String get title => name.trim().isNotEmpty ? name.trim() : phone;

  List<String> get tags => tagList
      .split(RegExp(r'[,;|]'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

class WaContactPage {
  const WaContactPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<WaContactRecord> items;
  final int page;
  final int lastPage;
  final int total;

  bool get hasMore => page < lastPage;
}

/// A number that is never messaged (GET /blacklist).
class WaBlacklistEntry {
  const WaBlacklistEntry({
    required this.id,
    required this.phone,
    required this.name,
    required this.reason,
    this.createdAt,
  });

  factory WaBlacklistEntry.fromJson(Map<String, dynamic> j) => WaBlacklistEntry(
    id: asStr(j['id']),
    phone: asStr(j['phone']),
    name: asStr(j['name']),
    reason: asStr(j['reason']),
    createdAt: asDate(j['created_at']),
  );

  final String id;
  final String phone;
  final String name;
  final String reason;
  final DateTime? createdAt;
}

/// A campaign (GET /campaigns): a template sent to an audience of contacts.
class WaCampaign {
  const WaCampaign({
    required this.id,
    required this.name,
    required this.status,
    required this.templateName,
    required this.numberLabel,
    required this.total,
    required this.sent,
    required this.delivered,
    required this.read,
    required this.failed,
    required this.replied,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.source = '',
  });

  factory WaCampaign.fromJson(Map<String, dynamic> j) {
    final template = asMap(j['template']);
    return WaCampaign(
      id: asStr(j['id']),
      name: asStr(j['name']),
      status: asStr(j['status']),
      templateName: asStr(template['name']),
      numberLabel: asStr(asMap(j['phone_number'])['display_phone_number']),
      total: asInt(j['total_recipients']),
      sent: asInt(j['sent_count']),
      delivered: asInt(j['delivered_count']),
      read: asInt(j['read_count']),
      failed: asInt(j['failed_count']),
      replied: asInt(j['replied_count']),
      scheduledAt: asDate(j['scheduled_at']),
      startedAt: asDate(j['started_at']),
      completedAt: asDate(j['completed_at']),
      createdAt: asDate(j['created_at']),
      source: asStr(asMap(j['audience_filter'])['source']),
    );
  }

  final String id;
  final String name;

  /// draft, scheduled, running, paused, completed or cancelled.
  final String status;
  final String templateName;
  final String numberLabel;
  final int total;
  final int sent;
  final int delivered;
  final int read;
  final int failed;
  final int replied;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final String source;

  /// Messages handled so far (sent or failed).
  int get done => sent + failed;

  bool get isRunning => status == 'running';
  bool get canStart => status == 'draft' || status == 'scheduled';
  bool get canDelete => status == 'draft';
  bool get canCancel =>
      const {'draft', 'scheduled', 'running', 'paused'}.contains(status);
}

class WaCampaignPage {
  const WaCampaignPage({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<WaCampaign> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

/// One recipient of a campaign and how its message went.
class WaCampaignRecipient {
  const WaCampaignRecipient({
    required this.status,
    required this.name,
    required this.phone,
  });

  factory WaCampaignRecipient.fromJson(Map<String, dynamic> j) {
    final c = asMap(j['contact']);
    return WaCampaignRecipient(
      status: asStr(j['status']),
      name: asStr(c['name']),
      phone: asStr(c['phone']),
    );
  }

  final String status;
  final String name;
  final String phone;

  String get title => name.trim().isNotEmpty ? name.trim() : phone;
}

class WaCampaignDetail {
  const WaCampaignDetail({
    required this.campaign,
    required this.recipients,
    required this.totalRecipients,
  });

  final WaCampaign campaign;
  final List<WaCampaignRecipient> recipients;
  final int totalRecipients;
}

class WaBulkRecipient {
  const WaBulkRecipient({
    required this.phone,
    required this.status,
    required this.error,
  });

  factory WaBulkRecipient.fromJson(Map<String, dynamic> j) => WaBulkRecipient(
    phone: asStr(j['phone']),
    status: asStr(j['status']),
    error: asStr(j['error_message']),
  );

  final String phone;

  /// pending, sent, delivered or failed.
  final String status;
  final String error;
}

/// A bulk send (GET /bulk-sends): one template to a typed list of numbers.
class WaBulkSend {
  const WaBulkSend({
    required this.id,
    required this.template,
    required this.language,
    required this.status,
    required this.total,
    required this.sent,
    required this.failed,
    required this.delivered,
    required this.recipients,
    this.numberLabel = '',
    this.createdAt,
  });

  factory WaBulkSend.fromJson(Map<String, dynamic> j) => WaBulkSend(
    id: asStr(j['uuid']).isEmpty ? asStr(j['id']) : asStr(j['uuid']),
    template: asStr(j['template_name']),
    language: asStr(j['language']),
    status: asStr(j['status']),
    total: asInt(j['total']),
    sent: asInt(j['sent_count']),
    failed: asInt(j['failed_count']),
    delivered: asInt(j['delivered_count']),
    recipients: asMaps(j['recipients']).map(WaBulkRecipient.fromJson).toList(),
    numberLabel: asStr(asMap(j['phone_number'])['display_phone_number']),
    createdAt: asDate(j['created_at']),
  );

  final String id;
  final String template;
  final String language;

  /// processing or completed (as the server names them).
  final String status;
  final int total;
  final int sent;
  final int failed;
  final int delivered;
  final List<WaBulkRecipient> recipients;
  final String numberLabel;
  final DateTime? createdAt;

  int get done => sent + failed;
  bool get processing => status == 'processing';
}

class WaBulkPage {
  const WaBulkPage({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<WaBulkSend> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

/// One keyword rule of a chatbot.
class WaChatRule {
  const WaChatRule({
    required this.id,
    required this.keyword,
    required this.matchType,
    required this.responseType,
    required this.responseText,
    required this.templateName,
    required this.priority,
    required this.isActive,
  });

  factory WaChatRule.fromJson(Map<String, dynamic> j) => WaChatRule(
    id: asStr(j['id']),
    keyword: asStr(j['keyword']),
    matchType: asStr(j['match_type']).isEmpty
        ? 'contains'
        : asStr(j['match_type']),
    responseType: asStr(j['response_type']).isEmpty
        ? 'text'
        : asStr(j['response_type']),
    responseText: asStr(j['response_text']),
    templateName: asStr(j['template_name']),
    priority: asInt(j['priority']),
    isActive: j['is_active'] != false && j['is_active'] != 0,
  );

  final String id;
  final String keyword;

  /// exact, contains, starts_with or regex.
  final String matchType;

  /// text or template.
  final String responseType;
  final String responseText;
  final String templateName;
  final int priority;
  final bool isActive;
}

class WaChatbot {
  const WaChatbot({
    required this.id,
    required this.name,
    required this.isActive,
    required this.isLeadFlow,
    required this.welcome,
    required this.fallback,
    required this.aiEnabled,
    required this.aiInstructions,
    required this.followupEnabled,
    required this.followupMessage,
    required this.rulesCount,
    required this.rules,
    this.numberLabel = '',
  });

  factory WaChatbot.fromJson(Map<String, dynamic> j) {
    final rules = asMaps(j['rules']).map(WaChatRule.fromJson).toList();
    final count = asInt(j['rules_count']);
    return WaChatbot(
      id: asStr(j['id']),
      name: asStr(j['name']),
      isActive: j['is_active'] == true || j['is_active'] == 1,
      isLeadFlow: j['is_lead_flow'] == true,
      welcome: asStr(j['welcome_message']),
      fallback: asStr(j['fallback_message']),
      aiEnabled: j['ai_enabled'] == true,
      aiInstructions: asStr(j['ai_instructions']),
      followupEnabled: j['followup_enabled'] == true,
      followupMessage: asStr(j['followup_message']),
      rulesCount: count == 0 ? rules.length : count,
      rules: rules,
      numberLabel: asStr(asMap(j['phone_number'])['display_phone_number']),
    );
  }

  final String id;
  final String name;
  final bool isActive;
  final bool isLeadFlow;
  final String welcome;
  final String fallback;
  final bool aiEnabled;
  final String aiInstructions;
  final bool followupEnabled;
  final String followupMessage;
  final int rulesCount;

  /// Only filled by the detail call.
  final List<WaChatRule> rules;
  final String numberLabel;
}

class WaChatbotPage {
  const WaChatbotPage({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<WaChatbot> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

/// GET /chatbots/lead-flow: the ready-made lead funnel, only for some accounts.
class WaLeadFlow {
  const WaLeadFlow({
    required this.available,
    required this.installed,
    required this.active,
    required this.steps,
  });

  factory WaLeadFlow.fromJson(Map<String, dynamic> j) => WaLeadFlow(
    available: j['available'] == true,
    installed: j['installed'] == true,
    active: j['active'] == true,
    steps: (j['steps'] is List)
        ? (j['steps'] as List)
              .map((e) {
                if (e is Map) {
                  final m = asMap(e.cast<String, dynamic>());
                  final t = asStr(m['title']).isEmpty
                      ? asStr(m['name'])
                      : asStr(m['title']);
                  return t.isEmpty ? asStr(m['label']) : t;
                }
                return e.toString();
              })
              .where((s) => s.isNotEmpty)
              .toList()
        : <String>[],
  );

  final bool available;
  final bool installed;
  final bool active;
  final List<String> steps;
}

/// A WhatsApp automation (workflow). Its steps are drawn on a canvas on the
/// web, so the app only reads it and switches it on or off.
class WaWorkflow {
  const WaWorkflow({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.triggerType,
    required this.triggerConfig,
    required this.nodesCount,
    required this.executionsCount,
    this.activatedAt,
    this.createdAt,
  });

  factory WaWorkflow.fromJson(Map<String, dynamic> j) {
    final nodes = asMaps(j['nodes']);
    final nc = asInt(j['nodes_count']);
    return WaWorkflow(
      id: asStr(j['id']),
      name: asStr(j['name']),
      description: asStr(j['description']),
      status: asStr(j['status']),
      triggerType: asStr(j['trigger_type']),
      triggerConfig: asMap(j['trigger_config']),
      nodesCount: nc == 0 ? nodes.length : nc,
      executionsCount: asInt(j['executions_count']),
      activatedAt: asDate(j['activated_at']),
      createdAt: asDate(j['created_at']),
    );
  }

  final String id;
  final String name;
  final String description;

  /// draft, active or paused.
  final String status;
  final String triggerType;
  final Map<String, dynamic> triggerConfig;
  final int nodesCount;
  final int executionsCount;
  final DateTime? activatedAt;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
  bool get canActivate => status == 'draft' || status == 'paused';
  bool get canDelete => status == 'draft';

  /// "When a new contact is added", "When the message has a keyword", ...
  String get triggerLabel {
    switch (triggerType) {
      case 'new_contact':
        return 'A new contact is added';
      case 'incoming_message':
        return 'A message comes in';
      case 'keyword':
        final k = asStr(triggerConfig['keyword']);
        return k.isEmpty ? 'A message has a keyword' : 'A message says "$k"';
      case 'tag_added':
        final t = asStr(triggerConfig['tag']);
        return t.isEmpty ? 'A tag is added' : 'The tag "$t" is added';
      case 'tag_removed':
        final t = asStr(triggerConfig['tag']);
        return t.isEmpty ? 'A tag is removed' : 'The tag "$t" is removed';
      case 'scheduled':
        return 'On a schedule';
      default:
        return triggerType.isEmpty ? 'Unknown trigger' : triggerType;
    }
  }
}

class WaWorkflowPage {
  const WaWorkflowPage({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<WaWorkflow> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

/// One run of an automation for one contact.
class WaExecution {
  const WaExecution({
    required this.id,
    required this.status,
    required this.contactName,
    required this.contactPhone,
    this.startedAt,
    this.finishedAt,
  });

  factory WaExecution.fromJson(Map<String, dynamic> j) {
    final c = asMap(j['contact']);
    return WaExecution(
      id: asStr(j['id']),
      status: asStr(j['status']),
      contactName: asStr(c['name']),
      contactPhone: asStr(c['phone']),
      startedAt: asDate(j['started_at']),
      finishedAt: asDate(j['finished_at']),
    );
  }

  final String id;
  final String status;
  final String contactName;
  final String contactPhone;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  String get who => contactName.trim().isNotEmpty
      ? contactName.trim()
      : (contactPhone.isEmpty ? 'Unknown contact' : contactPhone);
}

class WaExecutionPage {
  const WaExecutionPage({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<WaExecution> items;
  final int page;
  final int lastPage;

  bool get hasMore => page < lastPage;
}

/// GET /analytics/dashboard: headline counts.
class WaDashboard {
  const WaDashboard({
    required this.contacts,
    required this.conversations,
    required this.openConversations,
    required this.messagesToday,
    required this.messagesWeek,
    required this.messagesMonth,
    required this.templatesApproved,
    required this.activeCampaigns,
    required this.totalCampaigns,
  });

  factory WaDashboard.fromJson(Map<String, dynamic> j) => WaDashboard(
    contacts: asInt(j['total_contacts']),
    conversations: asInt(j['total_conversations']),
    openConversations: asInt(j['open_conversations']),
    messagesToday: asInt(j['messages_today']),
    messagesWeek: asInt(j['messages_this_week']),
    messagesMonth: asInt(j['messages_this_month']),
    templatesApproved: asInt(j['templates_approved']),
    activeCampaigns: asInt(j['active_campaigns']),
    totalCampaigns: asInt(j['total_campaigns']),
  );

  final int contacts;
  final int conversations;
  final int openConversations;
  final int messagesToday;
  final int messagesWeek;
  final int messagesMonth;
  final int templatesApproved;
  final int activeCampaigns;
  final int totalCampaigns;
}

/// One day of the message funnel.
class WaDayStat {
  const WaDayStat({
    required this.date,
    this.sent = 0,
    this.delivered = 0,
    this.read = 0,
    this.failed = 0,
    this.inbound = 0,
  });

  factory WaDayStat.fromJson(Map<String, dynamic> j) => WaDayStat(
    date: DateTime.tryParse(asStr(j['date'])) ?? DateTime.now(),
    sent: asInt(j['sent']),
    delivered: asInt(j['delivered']),
    read: asInt(j['read']),
    failed: asInt(j['failed']),
    inbound: asInt(j['inbound']),
  );

  final DateTime date;
  final int sent;
  final int delivered;
  final int read;
  final int failed;
  final int inbound;
}

/// GET /analytics/messages: totals plus one entry per day, with quiet days
/// filled in as zeros so a chart has a steady time axis.
class WaMessageStats {
  const WaMessageStats({
    required this.days,
    required this.sent,
    required this.delivered,
    required this.read,
    required this.failed,
    required this.inbound,
    required this.deliveryRate,
    required this.readRate,
  });

  factory WaMessageStats.fromJson(Map<String, dynamic> j, int range) {
    final totals = asMap(j['totals']);
    final byDay = <String, WaDayStat>{};
    for (final d in asMaps(j['daily'])) {
      final s = WaDayStat.fromJson(d);
      byDay[_dayKey(s.date)] = s;
    }
    final today = DateTime.now();
    final days = <WaDayStat>[];
    for (var i = range - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      days.add(byDay[_dayKey(d)] ?? WaDayStat(date: d));
    }
    return WaMessageStats(
      days: days,
      sent: asInt(totals['total_sent']),
      delivered: asInt(totals['total_delivered']),
      read: asInt(totals['total_read']),
      failed: asInt(totals['total_failed']),
      inbound: asInt(totals['total_inbound']),
      deliveryRate: asDouble(totals['delivery_rate']),
      readRate: asDouble(totals['read_rate']),
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final List<WaDayStat> days;
  final int sent;
  final int delivered;
  final int read;
  final int failed;
  final int inbound;
  final double deliveryRate;
  final double readRate;
}

/// One campaign in GET /analytics/campaigns.
class WaCampaignStat {
  const WaCampaignStat({
    required this.name,
    required this.status,
    required this.recipients,
    required this.sent,
    required this.delivered,
    required this.read,
    required this.failed,
    required this.deliveryRate,
    required this.readRate,
  });

  factory WaCampaignStat.fromJson(Map<String, dynamic> j) => WaCampaignStat(
    name: asStr(j['name']),
    status: asStr(j['status']),
    recipients: asInt(j['total_recipients']),
    sent: asInt(j['sent_count']),
    delivered: asInt(j['delivered_count']),
    read: asInt(j['read_count']),
    failed: asInt(j['failed_count']),
    deliveryRate: asDouble(j['delivery_rate']),
    readRate: asDouble(j['read_rate']),
  );

  final String name;
  final String status;
  final int recipients;
  final int sent;
  final int delivered;
  final int read;
  final int failed;
  final double deliveryRate;
  final double readRate;
}
