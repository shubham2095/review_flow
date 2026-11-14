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
