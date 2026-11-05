import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../models/gbp_models.dart';
import 'api_service.dart';

enum GbpConnectStatus { success, cancelled, invalidState, tokenFailed }

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

  static Future<void> disconnect() async {
    await _api.delete('/gbp/connection');
  }

  static Future<void> setLocationHidden(String id, bool hidden) async {
    await _api.post('/gbp/locations/$id/hidden', body: {'hidden': hidden});
  }
}
