import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../models/gbp_models.dart';
import 'api_service.dart';

enum GbpConnectStatus { success, cancelled, invalidState, tokenFailed }

class ReplyDraft {
  ReplyDraft({required this.draft, required this.source, required this.credits});

  final String draft;
  final String source;
  final int credits;

  bool get isAi => source == 'ai';
}

/// Calls for the Google Business Profile module (/gbp/*).
class GbpService {
  GbpService._();

  static final _api = ApiService.instance;

  static Future<GbpOverview> overview() async =>
      GbpOverview.fromJson(await _api.get('/gbp/overview'));

  /// Opens Google's consent screen in a secure browser tab. The backend sends the
  /// browser back to eydia://gbp-connected?status=..., which returns control here.
  static Future<GbpConnectStatus> connectGoogle() async {
    final res = await _api.get('/gbp/connect?mobile=1');
    final url = asStr(res['url']);
    if (url.isEmpty) {
      throw ApiException('Could not start the Google connection.');
    }

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'eydia',
      );
    } catch (_) {
      // The user closed the browser tab or the OS cancelled the flow.
      return GbpConnectStatus.cancelled;
    }

    switch (Uri.parse(result).queryParameters['status']) {
      case 'success':
        return GbpConnectStatus.success;
      case 'invalid_state':
        return GbpConnectStatus.invalidState;
      case 'token_failed':
        return GbpConnectStatus.tokenFailed;
      default:
        return GbpConnectStatus.cancelled;
    }
  }

  /// Pulls locations and reviews from Google. Can take a while on big accounts.
  static Future<GbpSyncResult> sync() async => GbpSyncResult.fromJson(
        await _api.post('/gbp/sync', timeout: kAiTimeout),
      );

  /// Lightweight location list (the full overview is much heavier). Hidden
  /// locations are included with isHidden set; callers filter as needed.
  static Future<List<GbpLocation>> locations() async {
    final res = await _api.get('/gbp/locations');
    return asMaps(res['locations']).map(GbpLocation.fromJson).toList();
  }

  /// Connection status, including the Google account and whether to reconnect.
  static Future<GbpConnection> connection() async =>
      GbpConnection.fromJson(await _api.get('/gbp/connection'));

  static String _pageQuery({
    required int page,
    required int perPage,
    String? locationId,
    Map<String, String> extra = const {},
  }) {
    return Uri(
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        'location': ?locationId,
        ...extra,
      },
    ).query;
  }

  /// One page of reviews, newest first. [rating] and [unreplied] filter on the server.
  static Future<PagedResult<GbpReview>> reviewsPage({
    required int page,
    int perPage = 30,
    String? locationId,
    bool unreplied = false,
    int? rating,
  }) async {
    final query = _pageQuery(
      page: page,
      perPage: perPage,
      locationId: locationId,
      extra: {
        if (unreplied) 'unreplied': '1',
        if (rating != null) 'rating': '$rating',
      },
    );
    final res = await _api.get('/gbp/reviews?$query');
    final items = asMaps(res['reviews']).map(GbpReview.fromJson).toList();
    return PagedResult(
      items,
      PageMeta.fromJson(asMap(res['meta']), fallbackTotal: items.length),
    );
  }

  /// Posts the reply to Google and stores it. Returns the updated review.
  static Future<GbpReview> replyToReview(String id, String reply) async {
    final res = await _api.post(
      '/gbp/reviews/$id/reply',
      body: {'reply': reply},
      timeout: kAiTimeout,
    );
    return GbpReview.fromJson(asMap(res['review']));
  }

  /// AI draft for a review. Costs credits; the server falls back to a template
  /// when AI is unavailable (source == 'fallback', no credits charged).
  static Future<ReplyDraft> suggestReply(String id) async {
    final res = await _api.post('/gbp/reviews/$id/suggest', timeout: kAiTimeout);
    return ReplyDraft(
      draft: asStr(res['draft']),
      source: asStr(res['source']),
      credits: asInt(res['credits']),
    );
  }

  // ---- Posts ----

  static String _locationQuery(String? id) => id == null ? '' : '?location=$id';

  static Future<PagedResult<GbpPost>> postsPage({
    required int page,
    int perPage = 20,
    String? locationId,
  }) async {
    final res = await _api.get(
      '/gbp/posts?${_pageQuery(page: page, perPage: perPage, locationId: locationId)}',
    );
    final items = asMaps(res['posts']).map(GbpPost.fromJson).toList();
    return PagedResult(
      items,
      PageMeta.fromJson(asMap(res['meta']), fallbackTotal: items.length),
    );
  }

  static Future<GbpPost> createPost(Map<String, dynamic> body) async {
    final res = await _api.post('/gbp/posts', body: body);
    return GbpPost.fromJson(asMap(res['post']));
  }

  static Future<GbpPost> updatePost(String id, Map<String, dynamic> body) async {
    final res = await _api.put('/gbp/posts/$id', body: body);
    return GbpPost.fromJson(asMap(res['post']));
  }

  /// Pushes the post to Google. Throws (502) with Google's reason if it refuses.
  static Future<GbpPost> publishPost(String id) async {
    final res = await _api.post('/gbp/posts/$id/publish', timeout: kAiTimeout);
    return GbpPost.fromJson(asMap(res['post']));
  }

  static Future<void> deletePost(String id) async {
    await _api.delete('/gbp/posts/$id');
  }

  static Future<AiText> generatePostText({
    required String topic,
    required String type,
    String? locationId,
    String? imageUrl,
  }) async {
    final res = await _api.post(
      '/gbp/posts/generate',
      body: {
        'topic': topic,
        'type': type,
        'location': ?locationId,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      },
      timeout: kAiTimeout,
    );
    return AiText(
      text: asStr(res['text']),
      source: asStr(res['source']),
      credits: asInt(res['credits']),
    );
  }

  /// AI content plan: creates [count] scheduled posts. Images make it much slower.
  static Future<({int created, String message, int credits})> autoPlan({
    String? locationId,
    required int count,
    required int cadenceDays,
    required bool withImages,
  }) async {
    final res = await _api.post(
      '/gbp/posts/auto-plan',
      body: {
        'location': ?locationId,
        'count': count,
        'cadence_days': cadenceDays,
        'with_images': withImages,
      },
      timeout: const Duration(seconds: 240),
    );
    return (
      created: asInt(res['created']),
      message: asStr(res['message']),
      credits: asInt(res['credits']),
    );
  }

  // ---- Insights, audit, optimize, assistant ----

  static Future<InsightsData> insights({
    required int days,
    String? locationId,
  }) async {
    final res = await _api.get(
      '/gbp/insights?days=$days${locationId == null ? '' : '&location=$locationId'}',
    );
    return InsightsData.fromJson(res);
  }

  static Future<List<int>> insightsCsv({
    required int days,
    String? locationId,
  }) {
    return _api.getBytes(
      '/gbp/insights/export?days=$days${locationId == null ? '' : '&location=$locationId'}',
    );
  }

  static Future<GbpHealth> health() async =>
      GbpHealth.fromJson(await _api.get('/gbp/health'));

  /// One-click optimization plan. Costs credits when the AI answers.
  static Future<OptimizeResult> optimize() async => OptimizeResult.fromJson(
        await _api.post('/gbp/optimize', timeout: kAiTimeout),
      );

  static Future<AiText> assistantChat(String message) async {
    final res = await _api.post(
      '/assistant/chat',
      body: {'message': message},
      timeout: kAiTimeout,
    );
    return AiText(
      text: asStr(res['answer']),
      source: asStr(res['source']),
      credits: asInt(res['credits']),
    );
  }

  // ---- Business profile ----

  static Future<BusinessProfile> profile({String? locationId}) async {
    final res = await _api.get('/gbp/profile${_locationQuery(locationId)}');
    return BusinessProfile.fromJson(asMap(res['profile']));
  }

  /// Saves in Eydia and, when Google is connected, pushes name, phone, website,
  /// description and hours to Google. [message] says which of the two happened.
  static Future<({BusinessProfile profile, bool syncedToGoogle, String message})>
      updateProfile(String? locationId, Map<String, dynamic> body) async {
    final res = await _api.put(
      '/gbp/profile${_locationQuery(locationId)}',
      body: body,
    );
    return (
      profile: BusinessProfile.fromJson(asMap(res['profile'])),
      syncedToGoogle: res['synced_to_google'] == true,
      message: asStr(res['message']),
    );
  }

  static Future<AiText> aiRewriteDescription({
    String? locationId,
    List<String> keywords = const [],
  }) async {
    final res = await _api.post(
      '/gbp/profile/ai-rewrite',
      body: {'location': ?locationId, if (keywords.isNotEmpty) 'keywords': keywords},
      timeout: kAiTimeout,
    );
    return AiText(
      text: asStr(res['description']),
      source: asStr(res['source']),
      credits: asInt(res['credits']),
    );
  }

  // ---- Photos ----

  static Future<PagedResult<GbpPhoto>> photosPage({
    required int page,
    int perPage = 20,
    String? locationId,
  }) async {
    final res = await _api.get(
      '/gbp/photos?${_pageQuery(page: page, perPage: perPage, locationId: locationId)}',
    );
    final items = asMaps(res['photos']).map(GbpPhoto.fromJson).toList();
    return PagedResult(
      items,
      PageMeta.fromJson(asMap(res['meta']), fallbackTotal: items.length),
    );
  }

  static Future<GbpPhoto> createPhoto(Map<String, dynamic> body) async {
    final res = await _api.post('/gbp/photos', body: body);
    return GbpPhoto.fromJson(asMap(res['photo']));
  }

  static Future<GbpPhoto> publishPhoto(String id) async {
    final res = await _api.post('/gbp/photos/$id/publish', timeout: kAiTimeout);
    return GbpPhoto.fromJson(asMap(res['photo']));
  }

  static Future<void> deletePhoto(String id) async {
    await _api.delete('/gbp/photos/$id');
  }

  static Future<AiText> photoCaption({
    required String topic,
    String? locationId,
  }) async {
    final res = await _api.post(
      '/gbp/photos/caption',
      body: {'topic': topic, 'location': ?locationId},
      timeout: kAiTimeout,
    );
    return AiText(
      text: asStr(res['text']),
      source: asStr(res['source']),
      credits: asInt(res['credits']),
    );
  }

  /// Uploads an image and returns its public https URL (what posts and photos need).
  static Future<String> uploadImage(List<int> bytes, String filename) async {
    final res = await _api.upload(
      '/gbp/upload',
      field: 'file',
      bytes: bytes,
      filename: filename,
    );
    final url = asStr(res['url']);
    if (url.isEmpty) throw ApiException('Image upload failed. Please try again.');
    return url;
  }

  static Future<void> disconnect() async {
    await _api.delete('/gbp/connection');
  }

  static Future<void> setLocationHidden(String id, bool hidden) async {
    await _api.post('/gbp/locations/$id/hidden', body: {'hidden': hidden});
  }
}
