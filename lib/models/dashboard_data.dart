import 'package:flutter/material.dart';

Color _hexColor(String? hex) {
  if (hex == null || hex.length != 7) return Colors.grey;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

int _int(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toInt() ?? 0;

double _double(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toDouble() ?? 0;

String _str(dynamic v) => v?.toString() ?? '';

class SubScore {
  SubScore({
    required this.label,
    required this.score,
    required this.detail,
    required this.color,
    required this.icon,
  });

  factory SubScore.fromJson(Map<String, dynamic> j) => SubScore(
        label: _str(j['label']),
        score: _int(j['score']),
        detail: _str(j['detail']),
        color: _hexColor(j['color'] as String?),
        icon: _str(j['icon']),
      );

  final String label;
  final int score;
  final String detail;
  final Color color;
  final String icon;
}

class DoNextItem {
  DoNextItem({
    required this.title,
    required this.why,
    required this.impact,
    required this.module,
    required this.icon,
  });

  factory DoNextItem.fromJson(Map<String, dynamic> j) => DoNextItem(
        title: _str(j['title']),
        why: _str(j['why']),
        impact: _str(j['impact']),
        module: _str(j['module']),
        icon: _str(j['icon']),
      );

  final String title;
  final String why;
  final String impact;
  final String module;
  final String icon;
}

class LocationItem {
  LocationItem({
    required this.id,
    required this.title,
    required this.address,
    required this.clientName,
    required this.totalReviews,
    required this.avgRating,
  });

  factory LocationItem.fromJson(Map<String, dynamic> j) => LocationItem(
        id: _int(j['id']),
        title: _str(j['title']),
        address: _str(j['address']),
        clientName: _str(j['client_name']),
        totalReviews: _int(j['total_reviews']),
        avgRating: _double(j['avg_rating']),
      );

  final int id;
  final String title;
  final String address;
  final String clientName;
  final int totalReviews;
  final double avgRating;
}

class RecentReview {
  RecentReview({
    required this.id,
    required this.reviewerName,
    required this.starRating,
    required this.comment,
    required this.locationTitle,
    required this.reviewTime,
  });

  factory RecentReview.fromJson(Map<String, dynamic> j) => RecentReview(
        id: _int(j['id']),
        reviewerName: _str(j['reviewer_name']),
        starRating: _int(j['star_rating']),
        comment: j['comment'] as String?,
        locationTitle: j['location_title'] as String?,
        reviewTime: j['review_time'] as String?,
      );

  final int id;
  final String reviewerName;
  final int starRating;
  final String? comment;
  final String? locationTitle;
  final String? reviewTime;
}

class DashboardData {
  DashboardData({
    required this.overall,
    required this.subScores,
    required this.doNext,
    required this.totalReviews,
    required this.avgRating,
    required this.replied,
    required this.unreplied,
    required this.hasGoogle,
    required this.locations,
    required this.recentReviews,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final health = j['health'] as Map<String, dynamic>? ?? {};
    final stats = j['stats'] as Map<String, dynamic>? ?? {};

    List<Map<String, dynamic>> listOf(dynamic v) =>
        (v as List? ?? []).cast<Map<String, dynamic>>();

    return DashboardData(
      overall: _int(health['overall']),
      subScores: listOf(health['subScores']).map(SubScore.fromJson).toList(),
      doNext: listOf(health['doNext']).map(DoNextItem.fromJson).toList(),
      totalReviews: _int(stats['total_reviews']),
      avgRating: _double(stats['avg_rating']),
      replied: _int(stats['replied']),
      unreplied: _int(stats['unreplied']),
      hasGoogle: j['has_google'] as bool? ?? false,
      locations: listOf(j['locations']).map(LocationItem.fromJson).toList(),
      recentReviews: listOf(j['recent_reviews']).map(RecentReview.fromJson).toList(),
    );
  }

  final int overall;
  final List<SubScore> subScores;
  final List<DoNextItem> doNext;
  final int totalReviews;
  final double avgRating;
  final int replied;
  final int unreplied;
  final bool hasGoogle;
  final List<LocationItem> locations;
  final List<RecentReview> recentReviews;
}
