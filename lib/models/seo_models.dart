import 'gbp_models.dart' show asDate, asInt, asMap, asMaps, asStr;

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/// A business location the SEO tools can be tied to.
class SeoPlace {
  const SeoPlace({required this.id, required this.name});

  factory SeoPlace.fromJson(Map<String, dynamic> j) =>
      SeoPlace(id: asStr(j['id']), name: asStr(j['name']));

  final String id;
  final String name;
}

/// What the connected Business Profile already says, so forms start filled in.
class SeoContext {
  const SeoContext({
    this.business = '',
    this.city = '',
    this.industry = '',
    this.locationId = '',
  });

  factory SeoContext.fromJson(Map<String, dynamic> j) => SeoContext(
    business: asStr(j['business']),
    city: asStr(j['city']),
    industry: asStr(j['industry']),
    locationId: asStr(j['location_id']),
  );

  final String business;
  final String city;
  final String industry;
  final String locationId;
}

/// GET /seo/overview.
class SeoOverview {
  const SeoOverview({
    this.keywords = 0,
    this.competitors = 0,
    this.checksThisMonth = 0,
    this.aiConfigured = true,
    this.locations = const [],
    this.context,
  });

  factory SeoOverview.fromJson(Map<String, dynamic> j) => SeoOverview(
    keywords: asInt(j['keywords']),
    competitors: asInt(j['competitors']),
    checksThisMonth: asInt(j['checks_this_month']),
    aiConfigured: j['ai_configured'] != false,
    locations: asMaps(j['locations']).map(SeoPlace.fromJson).toList(),
    context: j['context'] is Map
        ? SeoContext.fromJson(asMap(j['context']))
        : null,
  );

  final int keywords;
  final int competitors;
  final int checksThisMonth;

  /// False when the server has no AI key: checks then give general tips only.
  final bool aiConfigured;
  final List<SeoPlace> locations;
  final SeoContext? context;
}

/// A tracked search phrase: GET /seo/keywords.
class SeoKeyword {
  const SeoKeyword({
    required this.id,
    required this.keyword,
    this.city = '',
    this.locationName = '',
    this.latestRank = '',
    this.checks = 0,
    this.lastCheckedAt,
  });

  factory SeoKeyword.fromJson(Map<String, dynamic> j) => SeoKeyword(
    id: asStr(j['id']),
    keyword: asStr(j['keyword']),
    city: asStr(j['city']),
    locationName: asStr(asMap(j['location'])['name']),
    latestRank: asStr(j['latest_rank']),
    checks: asInt(j['checks']),
    lastCheckedAt: asDate(j['last_checked_at']),
  );

  final String id;
  final String keyword;
  final String city;
  final String locationName;

  /// "Top 3", "4-10", "Not in top 10" (an AI estimate) or empty.
  final String latestRank;
  final int checks;
  final DateTime? lastCheckedAt;
}

/// One past rank check: GET /seo/keywords/{id}/history.
class SeoSnapshot {
  const SeoSnapshot({
    required this.rank,
    this.source = '',
    this.summary = '',
    this.checkedAt,
  });

  factory SeoSnapshot.fromJson(Map<String, dynamic> j) => SeoSnapshot(
    rank: asStr(j['rank']),
    source: asStr(j['source']),
    summary: asStr(j['summary']),
    checkedAt: asDate(j['checked_at']),
  );

  final String rank;
  final String source;
  final String summary;
  final DateTime? checkedAt;
}

/// What a rank check found: POST /seo/keywords/{id}/check `result`.
class SeoRankResult {
  const SeoRankResult({
    required this.source,
    this.rank = '',
    this.summary = '',
    this.tips = const [],
  });

  factory SeoRankResult.fromJson(Map<String, dynamic> j) => SeoRankResult(
    source: asStr(j['source']),
    rank: asStr(j['rank']),
    summary: asStr(j['summary']),
    tips: _strings(j['tips']),
  );

  /// `ai`, or `fallback` when the server has no AI and only gave general tips.
  final String source;
  final String rank;
  final String summary;
  final List<String> tips;

  bool get isAi => source == 'ai';
}

/// Keyword ideas under one theme: POST /seo/keywords/generate `groups`.
class SeoIdeaGroup {
  const SeoIdeaGroup({required this.theme, required this.keywords});

  factory SeoIdeaGroup.fromJson(Map<String, dynamic> j) =>
      SeoIdeaGroup(theme: asStr(j['theme']), keywords: _strings(j['keywords']));

  final String theme;
  final List<String> keywords;
}

/// A business you compare yourself with: GET /seo/competitors.
class SeoCompetitor {
  const SeoCompetitor({
    required this.id,
    required this.name,
    this.city = '',
    this.locationName = '',
    this.analysis = '',
    this.lastAnalyzedAt,
  });

  factory SeoCompetitor.fromJson(Map<String, dynamic> j) => SeoCompetitor(
    id: asStr(j['id']),
    name: asStr(j['name']),
    city: asStr(j['city']),
    locationName: asStr(asMap(j['location'])['name']),
    analysis: asStr(j['analysis']),
    lastAnalyzedAt: asDate(j['last_analyzed_at']),
  );

  final String id;
  final String name;
  final String city;
  final String locationName;

  /// The last summary, or empty before the first analysis.
  final String analysis;
  final DateTime? lastAnalyzedAt;
}

/// A competitor analysis: POST /seo/competitors/{id}/analyze `result`.
class SeoAnalysis {
  const SeoAnalysis({
    required this.source,
    this.summary = '',
    this.strengths = const [],
    this.gaps = const [],
    this.actions = const [],
    this.myName = '',
    this.myAverage = 0,
    this.myReviews = 0,
  });

  factory SeoAnalysis.fromJson(Map<String, dynamic> j) {
    final mine = asMap(j['my_stats']);
    return SeoAnalysis(
      source: asStr(j['source']),
      summary: asStr(j['summary']),
      strengths: _strings(j['strengths']),
      gaps: _strings(j['gaps']),
      actions: _strings(j['actions']),
      myName: asStr(mine['name']),
      myAverage: num.tryParse(asStr(mine['avg']))?.toDouble() ?? 0,
      myReviews: asInt(mine['total']),
    );
  }

  final String source;
  final String summary;
  final List<String> strengths;
  final List<String> gaps;
  final List<String> actions;
  final String myName;
  final double myAverage;
  final int myReviews;

  bool get isAi => source == 'ai';
}
