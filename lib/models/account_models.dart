import 'gbp_models.dart';

class AutomationSettings {
  AutomationSettings({
    required this.autoReviewReplies,
    required this.autoPosts,
    required this.autoPhotos,
    required this.qrReviewAssist,
    required this.replyTone,
    required this.postFrequencyDays,
    required this.postQueueTarget,
    this.lastRunAt,
  });

  factory AutomationSettings.fromJson(Map<String, dynamic> j) =>
      AutomationSettings(
        autoReviewReplies: j['auto_review_replies'] == true,
        autoPosts: j['auto_posts'] == true,
        autoPhotos: j['auto_photos'] == true,
        qrReviewAssist: j['qr_review_assist'] == true,
        replyTone: asStr(j['reply_tone']),
        postFrequencyDays: asInt(j['post_frequency_days']).clamp(1, 30),
        postQueueTarget: asInt(j['post_queue_target']).clamp(1, 12),
        lastRunAt: asDate(j['last_run_at']),
      );

  final bool autoReviewReplies;
  final bool autoPosts;
  final bool autoPhotos;
  final bool qrReviewAssist;
  final String replyTone;
  final int postFrequencyDays;
  final int postQueueTarget;
  final DateTime? lastRunAt;
}

class AutomationData {
  AutomationData({
    required this.settings,
    required this.business,
    required this.hasLocation,
    required this.reviewUrl,
    required this.assistUrl,
    required this.assistUrlPreview,
  });

  factory AutomationData.fromJson(Map<String, dynamic> j) => AutomationData(
        settings: AutomationSettings.fromJson(asMap(j['automation'])),
        business: asStr(j['business']),
        hasLocation: j['has_location'] == true,
        reviewUrl: asStr(j['review_url']),
        assistUrl: asStr(j['assist_url']),
        assistUrlPreview: asStr(j['assist_url_preview']),
      );

  final AutomationSettings settings;
  final String business;
  final bool hasLocation;
  final String reviewUrl;

  /// Set only while QR review assist is switched on.
  final String assistUrl;

  /// Always available when the business has a review link, even if assist is off.
  final String assistUrlPreview;
}

class PlanInfo {
  PlanInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.priceDisplay,
    required this.billingPeriod,
    required this.features,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> j) {
    final f = j['features'];
    final features = <String>[];
    if (f is List) {
      features.addAll(f.map((e) => e.toString()));
    } else if (f is Map) {
      f.forEach((k, v) {
        if (v == true) features.add(k.toString());
      });
    }
    return PlanInfo(
      id: asStr(j['id']),
      name: asStr(j['name']),
      description: asStr(j['description']),
      priceDisplay: asStr(j['price_display']),
      billingPeriod: asStr(j['billing_period']),
      features: features,
    );
  }

  final String id;
  final String name;
  final String description;
  final String priceDisplay;
  final String billingPeriod;
  final List<String> features;
}

class SubscriptionInfo {
  SubscriptionInfo({
    required this.status,
    required this.planName,
    this.currentPeriodEnd,
    this.trialEndsAt,
    this.cancelledAt,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) {
    final plan = asMap(j['plan']);
    return SubscriptionInfo(
      status: asStr(j['status']),
      planName: asStr(plan['name']),
      currentPeriodEnd: asDate(j['current_period_end']),
      trialEndsAt: asDate(j['trial_ends_at']),
      cancelledAt: asDate(j['cancelled_at']),
    );
  }

  final String status;
  final String planName;
  final DateTime? currentPeriodEnd;
  final DateTime? trialEndsAt;
  final DateTime? cancelledAt;
}

class CreditEntry {
  CreditEntry({
    required this.delta,
    required this.description,
    required this.balanceAfter,
    this.at,
  });

  factory CreditEntry.fromJson(Map<String, dynamic> j) => CreditEntry(
        delta: asInt(j['delta']),
        description: asStr(j['description']).isEmpty
            ? asStr(j['action'])
            : asStr(j['description']),
        balanceAfter: asInt(j['balance_after']),
        at: asDate(j['at']),
      );

  final int delta;
  final String description;
  final int balanceAfter;
  final DateTime? at;
}

class CreditsInfo {
  CreditsInfo({
    required this.balance,
    required this.allowance,
    required this.ledger,
    this.resetAt,
  });

  factory CreditsInfo.fromJson(Map<String, dynamic> j) => CreditsInfo(
        balance: asInt(j['balance']),
        allowance: asInt(j['allowance']),
        resetAt: asDate(j['reset_at']),
        ledger: asMaps(j['ledger']).map(CreditEntry.fromJson).toList(),
      );

  final int balance;
  final int allowance;
  final DateTime? resetAt;
  final List<CreditEntry> ledger;
}

class CreditPackInfo {
  CreditPackInfo({
    required this.id,
    required this.name,
    required this.credits,
    required this.price,
  });

  factory CreditPackInfo.fromJson(Map<String, dynamic> j) => CreditPackInfo(
        id: asStr(j['id']),
        name: asStr(j['name']),
        credits: asInt(j['credits']),
        price: asDouble(j['price']),
      );

  final String id;
  final String name;
  final int credits;
  final double price;
}

class BillingInvoice {
  BillingInvoice({
    required this.number,
    required this.status,
    required this.total,
    this.issuedAt,
    this.paidAt,
  });

  factory BillingInvoice.fromJson(Map<String, dynamic> j) => BillingInvoice(
        number: asStr(j['number']),
        status: asStr(j['status']),
        total: asStr(j['total']),
        issuedAt: asDate(j['issued_at']),
        paidAt: asDate(j['paid_at']),
      );

  final String number;
  final String status;
  final String total;
  final DateTime? issuedAt;
  final DateTime? paidAt;
}

class SupportTicket {
  SupportTicket({
    required this.id,
    required this.ticketId,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    this.category,
    this.adminReply,
    this.createdAt,
    this.repliedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: asStr(j['id']),
        ticketId: asStr(j['ticket_id']),
        subject: asStr(j['subject']),
        description: asStr(j['description']),
        status: asStr(j['status']),
        priority: asStr(j['priority']),
        category: j['category']?.toString(),
        adminReply: j['admin_reply']?.toString(),
        createdAt: asDate(j['created_at']),
        repliedAt: asDate(j['replied_at']),
      );

  final String id;
  final String ticketId;
  final String subject;
  final String description;
  final String status;
  final String priority;
  final String? category;
  final String? adminReply;
  final DateTime? createdAt;
  final DateTime? repliedAt;

  bool get hasReply => (adminReply ?? '').trim().isNotEmpty;
}
