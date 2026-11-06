import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One saved server answer and when it was saved.
class SavedResponse {
  SavedResponse(this.data, this.savedAt);

  final dynamic data;
  final DateTime savedAt;
}

/// Keeps the last successful answer of each read-only (GET) call on the phone,
/// so screens still show something when the server cannot be reached.
///
/// Files live in the app's private storage and are wiped on logout. Everything
/// is best effort: a storage problem never turns into an error for the person.
class OfflineCache {
  OfflineCache._();

  static const _maxAge = Duration(days: 14);
  static const _maxNameLength = 180;
  static Directory? _dir;
  static bool _pruned = false;

  /// Admin data and sign-in calls are never kept, except who the user is: that
  /// lets the app open offline (the server still enforces the plan).
  static bool _cacheable(String path) {
    if (path.startsWith('/admin')) return false;
    if (path.startsWith('/auth') && !path.startsWith('/auth/me')) return false;
    return true;
  }

  static Future<Directory?> _directory() async {
    if (_dir != null) return _dir;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/offline_cache');
      if (!await dir.exists()) await dir.create(recursive: true);
      return _dir = dir;
    } catch (_) {
      return null;
    }
  }

  static String _name(String path) =>
      base64Url.encode(utf8.encode(path)).replaceAll('=', '');

  static Future<File?> _file(String path) async {
    if (!_cacheable(path)) return null;
    final name = _name(path);
    if (name.length > _maxNameLength) return null;
    final dir = await _directory();
    return dir == null ? null : File('${dir.path}/$name.json');
  }

  static Future<void> write(String path, dynamic payload) async {
    try {
      final file = await _file(path);
      if (file == null) return;
      await file.writeAsString(
        jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'data': payload,
        }),
        flush: true,
      );
      if (!_pruned) {
        _pruned = true;
        await _prune();
      }
    } catch (_) {}
  }

  static Future<SavedResponse?> read(String path) async {
    try {
      final file = await _file(path);
      if (file == null || !await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return null;
      final at = DateTime.tryParse('${json['saved_at']}');
      if (at == null || DateTime.now().difference(at) > _maxAge) return null;
      return SavedResponse(json['data'], at);
    } catch (_) {
      return null;
    }
  }

  /// Once per run: drop copies nobody has refreshed for two weeks.
  static Future<void> _prune() async {
    try {
      final dir = await _directory();
      if (dir == null) return;
      final cutoff = DateTime.now().subtract(_maxAge);
      await for (final entry in dir.list()) {
        if (entry is File && (await entry.lastModified()).isBefore(cutoff)) {
          await entry.delete();
        }
      }
    } catch (_) {}
  }

  /// On logout / session end: the next person must never see the last one's data.
  static Future<void> clear() async {
    try {
      final dir = await _directory();
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (_) {}
  }
}
