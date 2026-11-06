import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a half-written review reply on the phone, so closing the sheet by
/// accident (swipe, back, tapping outside) never loses what was typed.
/// Every call is best effort: a storage problem must never break replying.
class ReplyDrafts {
  ReplyDrafts._();

  static String _key(String reviewId) => 'reply_draft_$reviewId';

  static Future<String> read(String reviewId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key(reviewId)) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// An empty [text] removes the saved draft.
  static Future<void> save(String reviewId, String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (text.trim().isEmpty) {
        await prefs.remove(_key(reviewId));
      } else {
        await prefs.setString(_key(reviewId), text);
      }
    } catch (_) {}
  }

  static Future<void> clear(String reviewId) => save(reviewId, '');
}
