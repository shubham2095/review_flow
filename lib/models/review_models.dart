int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

String? _s(dynamic v) => v?.toString();

class LocationSummary {
  LocationSummary.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        title = _s(j['title']) ?? '',
        address = _s(j['address']) ?? '',
        clientName = _s(j['client_name']) ?? '',
        totalReviews = _i(j['total_reviews']),
        unrepliedCount = _i(j['unreplied_count']),
        negativeCount = _i(j['negative_count']),
        avgRating = _d(j['avg_rating']);

  final int id;
  final String title;
  final String address;
  final String clientName;
  final int totalReviews;
  final int unrepliedCount;
  final int negativeCount;
  final double avgRating;
}

class ReviewStats {
  ReviewStats.fromJson(Map<String, dynamic> j)
      : total = _i(j['total']),
        avg = _d(j['avg']),
        unreplied = _i(j['unreplied']),
        negative = _i(j['negative']);

  final int total;
  final double avg;
  final int unreplied;
  final int negative;
}

class ReviewItem {
  ReviewItem.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        reviewerName = _s(j['reviewer_name']) ?? 'Anonymous',
        starRating = _i(j['star_rating']),
        comment = _s(j['comment']),
        sentiment = _s(j['sentiment']),
        replyText = _s(j['reply_text']),
        reviewTime = _s(j['review_time']);

  final int id;
  final String reviewerName;
  final int starRating;
  final String? comment;
  final String? sentiment;
  final String? replyText;
  final String? reviewTime;

  bool get replied => (replyText ?? '').trim().isNotEmpty;

  String get dateLabel {
    final t = reviewTime ?? '';
    return t.length >= 10 ? t.substring(0, 10) : '';
  }
}

class LocationReviewsPage {
  LocationReviewsPage({
    required this.locationTitle,
    required this.stats,
    required this.reviews,
    required this.currentPage,
    required this.lastPage,
  });

  factory LocationReviewsPage.fromJson(Map<String, dynamic> j) {
    final reviewsBlock = j['reviews'] as Map<String, dynamic>? ?? {};
    final meta = j['meta'] as Map<String, dynamic>? ?? {};
    final location = j['location'] as Map<String, dynamic>? ?? {};
    final list = (reviewsBlock['data'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ReviewItem.fromJson)
        .toList();

    return LocationReviewsPage(
      locationTitle: _s(location['title']) ?? '',
      stats: ReviewStats.fromJson(j['stats'] as Map<String, dynamic>? ?? {}),
      reviews: list,
      currentPage: _i(meta['current_page']),
      lastPage: _i(meta['last_page']),
    );
  }

  final String locationTitle;
  final ReviewStats stats;
  final List<ReviewItem> reviews;
  final int currentPage;
  final int lastPage;
}
