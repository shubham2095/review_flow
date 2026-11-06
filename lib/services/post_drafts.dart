import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a new Google post that was being written on the phone, so closing the
/// editor by accident never loses it. Best effort: a storage problem must never
/// get in the way of writing a post.
class PostDrafts {
  PostDrafts._();

  static const _key = 'new_post_draft';

  static Future<Map<String, dynamic>?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(data));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
