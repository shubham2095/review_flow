import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gbp_models.dart';

/// The business locations of the signed-in account and the one the user is
/// looking at. A null selection means "all locations". Modules read [selectedId]
/// and pass it as `?location=` to the API.
class LocationStore {
  LocationStore._();

  static const _key = 'selected_location_id';

  static final ValueNotifier<List<GbpLocation>> locations =
      ValueNotifier<List<GbpLocation>>([]);
  static final ValueNotifier<String?> selectedId = ValueNotifier<String?>(null);

  static bool _restored = false;

  static GbpLocation? get selected {
    final id = selectedId.value;
    if (id == null) return null;
    for (final l in locations.value) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Called whenever fresh locations arrive (dashboard load, sync).
  static Future<void> setLocations(List<GbpLocation> list) async {
    if (!_restored) {
      _restored = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        selectedId.value = prefs.getString(_key);
      } catch (_) {}
    }
    locations.value = list;
    final id = selectedId.value;
    if (id != null && !list.any((l) => l.id == id)) {
      await select(null);
    }
  }

  static Future<void> select(String? id) async {
    selectedId.value = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, id);
      }
    } catch (_) {}
  }

  static Future<void> clear() async {
    locations.value = [];
    _restored = false;
    await select(null);
  }
}
