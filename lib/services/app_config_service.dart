import 'package:package_info_plus/package_info_plus.dart';

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
  AppGateResult(this.state, {this.message = '', this.updateUrl = ''});

  final AppGateState state;
  final String message;
  final String updateUrl;
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

  /// Fails open: if the config cannot be fetched (offline, server down) the app
  /// must still open, so any error means "ok".
  static Future<AppGateResult> check() async {
    try {
      final res = await ApiService.instance.getPublic(
        '/app/config',
        timeout: const Duration(seconds: 6),
      );
      final config = AppConfig.fromJson(res);

      if (config.maintenance) {
        return AppGateResult(
          AppGateState.maintenance,
          message: config.maintenanceMessage.isEmpty
              ? 'Eydia is undergoing scheduled maintenance. Please try again shortly.'
              : config.maintenanceMessage,
        );
      }

      final info = await PackageInfo.fromPlatform();
      if (config.minSupportedVersion.isNotEmpty &&
          compareVersions(info.version, config.minSupportedVersion) < 0) {
        return AppGateResult(
          AppGateState.updateRequired,
          updateUrl: config.updateUrl,
        );
      }
    } catch (_) {
      // Fail open.
    }
    return AppGateResult(AppGateState.ok);
  }
}
