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
