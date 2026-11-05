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

  /// Latest reviews (the API returns at most 200). Pass a location UUID to narrow it.
  static Future<List<GbpReview>> reviews({String? locationId}) async {
    final query = locationId == null ? '' : '?location=$locationId';
    final res = await _api.get('/gbp/reviews$query');
    return asMaps(res['reviews']).map(GbpReview.fromJson).toList();
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

  static Future<void> disconnect() async {
    await _api.delete('/gbp/connection');
  }

  static Future<void> setLocationHidden(String id, bool hidden) async {
    await _api.post('/gbp/locations/$id/hidden', body: {'hidden': hidden});
  }
}
