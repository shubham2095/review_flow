import '../models/gbp_models.dart' show asMap, asMaps;
import '../models/seo_models.dart';
import 'api_service.dart';

/// Local SEO (/api/v1/seo/...). Needs the `seo` plan feature. Checks and
/// analyses use AI credits, so they get the long AI timeout.
class SeoService {
  SeoService._();

  static final _api = ApiService.instance;

  static Future<SeoOverview> overview() async =>
      SeoOverview.fromJson(await _api.get('/seo/overview'));

  // ---- Keywords ----

  static Future<List<SeoKeyword>> keywords() async {
    final res = await _api.get('/seo/keywords');
    return asMaps(res['keywords']).map(SeoKeyword.fromJson).toList();
  }

  static Future<SeoKeyword> addKeyword({
    required String keyword,
    String city = '',
    String? locationId,
  }) async {
    final res = await _api.post(
      '/seo/keywords',
      body: {
        'keyword': keyword,
        if (city.isNotEmpty) 'city': city,
        'location_id': ?locationId,
      },
    );
    return SeoKeyword.fromJson(asMap(res['keyword']));
  }

  static Future<void> deleteKeyword(String id) async =>
      _api.delete('/seo/keywords/$id');

  /// Runs a rank check (uses credits). Returns the updated keyword and what
  /// was found.
  static Future<(SeoKeyword, SeoRankResult)> checkKeyword(String id) async {
    final res = await _api.post('/seo/keywords/$id/check', timeout: kAiTimeout);
    return (
      SeoKeyword.fromJson(asMap(res['keyword'])),
      SeoRankResult.fromJson(asMap(res['result'])),
    );
  }

  static Future<List<SeoSnapshot>> history(String id) async {
    final res = await _api.get('/seo/keywords/$id/history');
    return asMaps(res['snapshots']).map(SeoSnapshot.fromJson).toList();
  }

  /// AI keyword ideas in themed groups (uses credits).
  static Future<List<SeoIdeaGroup>> ideas({
    required String business,
    required String city,
    String industry = '',
  }) async {
    final res = await _api.post(
      '/seo/keywords/generate',
      body: {
        'business': business,
        'city': city,
        if (industry.isNotEmpty) 'industry': industry,
      },
      timeout: kAiTimeout,
    );
    return asMaps(res['groups']).map(SeoIdeaGroup.fromJson).toList();
  }

  // ---- Competitors ----

  static Future<List<SeoCompetitor>> competitors() async {
    final res = await _api.get('/seo/competitors');
    return asMaps(res['competitors']).map(SeoCompetitor.fromJson).toList();
  }

  static Future<SeoCompetitor> addCompetitor({
    required String name,
    String city = '',
    String? locationId,
  }) async {
    final res = await _api.post(
      '/seo/competitors',
      body: {
        'name': name,
        if (city.isNotEmpty) 'city': city,
        'location_id': ?locationId,
      },
    );
    return SeoCompetitor.fromJson(asMap(res['competitor']));
  }

  static Future<void> deleteCompetitor(String id) async =>
      _api.delete('/seo/competitors/$id');

  /// Compares your reviews with the competitor (uses credits).
  static Future<(SeoCompetitor, SeoAnalysis)> analyze(String id) async {
    final res = await _api.post(
      '/seo/competitors/$id/analyze',
      timeout: kAiTimeout,
    );
    return (
      SeoCompetitor.fromJson(asMap(res['competitor'])),
      SeoAnalysis.fromJson(asMap(res['result'])),
    );
  }
}
