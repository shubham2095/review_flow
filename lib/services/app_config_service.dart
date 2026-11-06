import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gbp_models.dart';
import 'api_service.dart';

/// Server-side switches from GET /app/config: forced update and maintenance.
class AppConfig {
  AppConfig({
    required this.minSupportedVersion,
    required this.latestVersion,
    required this.updateUrl,
    required this.maintenance,
    required this.maintenanceMessage,
  });

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        minSupportedVersion: asStr(j['min_supported_version']),
        latestVersion: asStr(j['latest_version']),
        updateUrl: asStr(j['update_url']),
        maintenance: j['maintenance'] == true,
        maintenanceMessage: asStr(j['maintenance_message']),
      );

  final String minSupportedVersion;
  final String latestVersion;
  final String updateUrl;
  final bool maintenance;
  final String maintenanceMessage;
}

enum AppGateState { ok, maintenance, updateRequired }

class AppGateResult {
  AppGateResult(
    this.state, {
    this.message = '',
    this.updateUrl = '',
    this.latestVersion = '',
  });

  final AppGateState state;
  final String message;
  final String updateUrl;
  final String latestVersion;
}

class AppConfigService {
  AppConfigService._();

  /// Compares dotted versions ("1.0.10" > "1.0.2"). Non-numeric parts count as 0.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final x = parts(a);
    final y = parts(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0;
      final yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi.compareTo(yi);
    }
    return 0;
  }

  static const _kMinVersionKey = 'app_min_supported_version';
  static const _kUpdateUrlKey = 'app_update_url';

  /// Used when the server does not send a store link.
  static const defaultUpdateUrl =
      'https://play.google.com/store/apps/details?id=com.heltog.review_flow';

  static Future<void> _remember(AppConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMinVersionKey, config.minSupportedVersion);
      await prefs.setString(_kUpdateUrlKey, config.updateUrl);
    } catch (_) {}
  }

  /// If the server cannot be reached, still enforce the last minimum version it
  /// told us about, so a forced update cannot be skipped by going offline.
  static Future<AppGateResult?> _fromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final min = prefs.getString(_kMinVersionKey) ?? '';
      if (min.isEmpty) return null;
      final info = await PackageInfo.fromPlatform();
      if (compareVersions(info.version, min) < 0) {
        return AppGateResult(
          AppGateState.updateRequired,
          updateUrl: prefs.getString(_kUpdateUrlKey) ?? '',
        );
      }
    } catch (_) {}
    return null;
  }

  /// Fails open when nothing is known: if the config cannot be fetched (offline,
  /// server down) and no earlier minimum version was saved, the app still opens,
  /// so an error never locks anyone out or crashes the app.
  static Future<AppGateResult> check() async {
    try {
      final res = await ApiService.instance.getPublic(
        '/app/config',
        timeout: const Duration(seconds: 6),
      );
      final config = AppConfig.fromJson(res);
      await _remember(config);

      final info = await PackageInfo.fromPlatform();
      // An outdated version is blocked even during maintenance, so the update
      // prompt is what people see.
      if (config.minSupportedVersion.isNotEmpty &&
          compareVersions(info.version, config.minSupportedVersion) < 0) {
        return AppGateResult(
          AppGateState.updateRequired,
          updateUrl: config.updateUrl,
          latestVersion: config.latestVersion,
        );
      }

      if (config.maintenance) {
        return AppGateResult(
          AppGateState.maintenance,
          message: config.maintenanceMessage.isEmpty
              ? 'Eydia is undergoing scheduled maintenance. Please try again shortly.'
              : config.maintenanceMessage,
        );
      }
      return AppGateResult(AppGateState.ok);
    } catch (_) {
      return await _fromCache() ?? AppGateResult(AppGateState.ok);
    }
  }
}
