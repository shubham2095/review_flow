import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small best-effort store for half-written forms (a support ticket, a note),
/// so closing a sheet by accident never loses what was typed. A storage problem
/// must never get in the way of the form itself.
class LocalDraft {
  LocalDraft._();

  static String _k(String key) => 'draft_$key';

  static Future<Map<String, dynamic>?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_k(key));
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_k(key), jsonEncode(data));
    } catch (_) {}
  }

  static Future<void> clear(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_k(key));
    } catch (_) {}
  }
}
