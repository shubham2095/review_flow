import 'package:flutter/material.dart';

/// Tolerant JSON readers: Laravel sends decimals as strings and omits empty fields.
int asInt(dynamic v) => num.tryParse(v?.toString() ?? '')?.toInt() ?? 0;
double asDouble(dynamic v) => num.tryParse(v?.toString() ?? '')?.toDouble() ?? 0;
String asStr(dynamic v) => v?.toString() ?? '';
DateTime? asDate(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

Map<String, dynamic> asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : <String, dynamic>{};

List<Map<String, dynamic>> asMaps(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : [];

Color _hexColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  final clean = hex.replaceFirst('#', '');
  final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return value == null ? fallback : Color(value);
}

class GbpLocation {
  GbpLocation({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.website = '',
    this.category = '',
    this.rating = 0,
    this.reviewCount = 0,
    this.isVerified = false,
    this.isHidden = false,
    this.lastSyncedAt,
  });

  factory GbpLocation.fromJson(Map<String, dynamic> j) {
    final total = j['total_reviews'] ?? j['review_count'];
    final avg = j['avg_rating'] ?? j['rating'];
    return GbpLocation(
      id: asStr(j['id']),
      name: asStr(j['name']),
      address: asStr(j['address']),
      phone: asStr(j['phone']),
      website: asStr(j['website']),
      category: asStr(j['category']),
      rating: asDouble(avg),
      reviewCount: asInt(total),
      isVerified: j['is_verified'] == true,
      isHidden: j['is_hidden'] == true,
      lastSyncedAt: asDate(j['last_synced_at']),
    );
  }

  final String id;
  final String name;
  final String address;
  final String phone;
  final String website;
  final String category;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final bool isHidden;
  final DateTime? lastSyncedAt;
}

class GbpReview {
  GbpReview({
    required this.id,
    required this.authorName,
    required this.rating,
    this.locationId,
    this.locationName,
    this.authorPhoto,
    this.comment,
    this.reply,
    this.draftReply,
    this.sentiment,
    this.repliedAt,
    this.reviewedAt,
  });

  factory GbpReview.fromJson(Map<String, dynamic> j) {
    final loc = j['location'];
    return GbpReview(
      id: asStr(j['id']),
      authorName: asStr(j['author_name']),
      rating: asInt(j['rating']),
      locationId: loc is Map ? asStr(loc['id']) : null,
      locationName: loc is Map ? asStr(loc['name']) : null,
      authorPhoto: j['author_photo']?.toString(),
      comment: j['comment']?.toString(),
      reply: j['reply']?.toString(),
      draftReply: j['draft_reply']?.toString(),
      sentiment: j['sentiment']?.toString(),
      repliedAt: asDate(j['replied_at']),
      reviewedAt: asDate(j['reviewed_at']),
    );
  }

  final String id;
  final String authorName;
  final int rating;
  final String? locationId;
  final String? locationName;
  final String? authorPhoto;
  final String? comment;
  final String? reply;
  final String? draftReply;
  final String? sentiment;
  final DateTime? repliedAt;
  final DateTime? reviewedAt;

  bool get hasReply => (reply ?? '').trim().isNotEmpty;
}

class HealthSub {
  HealthSub({
    required this.key,
    required this.label,
    required this.icon,
    required this.score,
    required this.detail,
    required this.color,
  });

  factory HealthSub.fromJson(Map<String, dynamic> j) => HealthSub(
        key: asStr(j['key']),
        label: asStr(j['label']),
        icon: asStr(j['icon']),
        score: asInt(j['score']).clamp(0, 100),
        detail: asStr(j['detail']),
        color: _hexColor(j['color']?.toString(), const Color(0xFF4C6FFF)),
      );

  final String key;
  final String label;
  final String icon;
  final int score;
  final String detail;
  final Color color;
}

class HealthAction {
  HealthAction({
    required this.priority,
    required this.icon,
    required this.module,
    required this.cta,
    required this.title,
    required this.why,
  });

  factory HealthAction.fromJson(Map<String, dynamic> j) => HealthAction(
        priority: asStr(j['priority']),
        icon: asStr(j['icon']),
        module: asStr(j['module']),
        cta: asStr(j['cta']),
        title: asStr(j['title'] ?? j['text']),
        why: asStr(j['why']),
      );

  final String priority;
  final String icon;
  final String module;
  final String cta;
  final String title;
  final String why;
}

class GbpHealth {
  GbpHealth({
    required this.score,
    required this.grade,
    required this.subScores,
    required this.actions,
  });

  factory GbpHealth.fromJson(Map<String, dynamic> j) => GbpHealth(
        score: asInt(j['score']).clamp(0, 100),
        grade: asStr(j['grade']),
        subScores: asMaps(j['sub_scores']).map(HealthSub.fromJson).toList(),
        actions: asMaps(j['actions']).map(HealthAction.fromJson).toList(),
      );

  final int score;
  final String grade;
  final List<HealthSub> subScores;
  final List<HealthAction> actions;

  /// The backend scores the Google connection 0 or 100.
  bool get googleConnected =>
      subScores.any((s) => s.key == 'connection' && s.score > 0);
}

class GbpOverview {
  GbpOverview({
    required this.locations,
    required this.hiddenLocations,
    required this.totalReviews,
    required this.averageRating,
    required this.replied,
    required this.unreplied,
    required this.ratingDistribution,
    required this.health,
    required this.posts,
    required this.photos,
    required this.creditBalance,
    required this.plan,
    required this.lastSyncedAt,
    required this.recentReviews,
  });

  factory GbpOverview.fromJson(Map<String, dynamic> j) {
    final stats = asMap(j['stats']);
    final summary = asMap(j['summary']);
    final dist = <int, int>{};
    final rawDist = stats['rating_distribution'];
    if (rawDist is Map) {
      rawDist.forEach((k, v) => dist[asInt(k)] = asInt(v));
    } else if (rawDist is List) {
      for (var i = 0; i < rawDist.length; i++) {
        dist[i] = asInt(rawDist[i]);
      }
    }
    return GbpOverview(
      locations: asMaps(j['locations']).map(GbpLocation.fromJson).toList(),
      hiddenLocations: asMaps(j['hidden_locations'])
          .map((m) => GbpLocation.fromJson({...m, 'is_hidden': true}))
          .toList(),
      totalReviews: asInt(stats['total_reviews']),
      averageRating: asDouble(stats['average_rating']),
      replied: asInt(stats['replied']),
      unreplied: asInt(stats['unreplied']),
      ratingDistribution: dist,
      health: GbpHealth.fromJson(asMap(j['health'])),
      posts: asInt(summary['posts']),
      photos: asInt(summary['photos']),
      creditBalance: asInt(summary['credit_balance']),
      plan: asStr(summary['plan']),
      lastSyncedAt: asDate(summary['last_synced_at']),
      recentReviews:
          asMaps(j['recent_reviews']).map(GbpReview.fromJson).toList(),
    );
  }

  final List<GbpLocation> locations;
  final List<GbpLocation> hiddenLocations;
  final int totalReviews;
  final double averageRating;
  final int replied;
  final int unreplied;
  final Map<int, int> ratingDistribution;
  final GbpHealth health;
  final int posts;
  final int photos;
  final int creditBalance;
  final String plan;
  final DateTime? lastSyncedAt;
  final List<GbpReview> recentReviews;

  bool get googleConnected => health.googleConnected;
}

class GbpSyncResult {
  GbpSyncResult({
    required this.synced,
    required this.locations,
    required this.reviews,
    required this.message,
  });

  factory GbpSyncResult.fromJson(Map<String, dynamic> j) => GbpSyncResult(
        synced: asInt(j['synced']),
        locations: asInt(j['locations']),
        reviews: asInt(j['reviews']),
        message: asStr(j['message']),
      );

  final int synced;
  final int locations;
  final int reviews;
  final String message;
}
