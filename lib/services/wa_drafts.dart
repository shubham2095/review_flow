import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Half-written chat replies, so leaving a chat never loses what was typed.
///
/// Best effort: a storage problem never gets in the way of chatting. Each draft
/// belongs to the signed-in person and one chat, so another account on the same
/// phone never sees it. Drafts older than 30 days (and any beyond the newest
/// 50) are removed by [prune].
class WaDrafts {
  WaDrafts._();

  static const _prefix = 'wa_draft_';

  static String _key(String userId, String chatId) =>
      '$_prefix${userId}_$chatId';

  static Future<String?> read(String userId, String chatId) async {
    if (userId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId, chatId));
      if (raw == null) return null;
      final data = jsonDecode(raw);
      final text = data is Map ? data['t']?.toString() : null;
      return text == null || text.trim().isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// Saves the draft; empty text removes it.
  static Future<void> save(String userId, String chatId, String text) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (text.trim().isEmpty) {
        await prefs.remove(_key(userId, chatId));
        return;
      }
      await prefs.setString(
        _key(userId, chatId),
        jsonEncode({'t': text, 'at': DateTime.now().millisecondsSinceEpoch}),
      );
    } catch (_) {}
  }

  static Future<void> clear(String userId, String chatId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId, chatId));
    } catch (_) {}
  }

  /// Removes drafts older than [maxAge] and keeps only the newest [keep].
  static Future<void> prune({
    Duration maxAge = const Duration(days: 30),
    int keep = 50,
    DateTime? now,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clock = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final kept = <String, int>{};
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        int? at;
        try {
          final data = jsonDecode(prefs.getString(key) ?? '');
          at = data is Map ? (data['at'] as num?)?.toInt() : null;
        } catch (_) {
          at = null;
        }
        if (at == null || clock - at > maxAge.inMilliseconds) {
          await prefs.remove(key);
        } else {
          kept[key] = at;
        }
      }
      if (kept.length > keep) {
        final newestFirst = kept.keys.toList()
          ..sort((a, b) => kept[b]!.compareTo(kept[a]!));
        for (final key in newestFirst.skip(keep)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }
}
