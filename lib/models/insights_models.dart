double _d(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toDouble() ?? 0;

const searchKeys = ['BUSINESS_IMPRESSIONS_DESKTOP_SEARCH', 'BUSINESS_IMPRESSIONS_MOBILE_SEARCH'];
const mapsKeys = ['BUSINESS_IMPRESSIONS_DESKTOP_MAPS', 'BUSINESS_IMPRESSIONS_MOBILE_MAPS'];
const callKeys = ['CALL_CLICKS'];
const directionKeys = ['BUSINESS_DIRECTION_REQUESTS'];
const websiteKeys = ['WEBSITE_CLICKS'];
const bookingKeys = ['BUSINESS_BOOKINGS'];

double sumKeys(Map<String, double> totals, List<String> keys) {
  return keys.fold(0.0, (acc, k) => acc + (totals[k] ?? 0));
}

class InsightLocation {
  InsightLocation.fromJson(Map<String, dynamic> j)
      : id = num.tryParse((j['id'])?.toString() ?? '')?.toInt() ?? 0,
        title = j['title']?.toString() ?? '';

  final int id;
  final String title;
}

class LocationInsight {
  LocationInsight({required this.title, required this.totals});

  final String title;
  final Map<String, double> totals;
}

class DailyPoint {
  DailyPoint({required this.date, required this.values});

  final String date;
  final Map<String, double> values;

  double get views => sumKeys(values, searchKeys) + sumKeys(values, mapsKeys);
}

class InsightsData {
  InsightsData({
    required this.hasGoogle,
    required this.error,
    required this.locations,
    required this.totals,
    required this.daily,
    required this.perLocation,
  });

  /// Backend har location ke liye `data` ko { metricName: { "YYYY-MM-DD": value } } bhejta hai.
  /// Totals aur daily numbers yahin calculate hote hain, kyunki backend ka precomputed
  /// `totals` / `daily_totals` is shape ke saath sahi nahi hai.
  factory InsightsData.fromJson(Map<String, dynamic> j) {
    final totals = <String, double>{};
    final dailyMap = <String, Map<String, double>>{};
    final perLocation = <LocationInsight>[];

    final metrics = j['metrics'];
    if (metrics is Map) {
      for (final entry in metrics.values) {
        final m = entry as Map<String, dynamic>;
        final locTotals = <String, double>{};
        final data = m['data'];

        if (data is Map) {
          data.forEach((metricName, series) {
            if (series is! Map) return;
            series.forEach((date, value) {
              final v = _d(value);
              final metric = metricName.toString();
              final day = date.toString();

              locTotals[metric] = (locTotals[metric] ?? 0) + v;
              totals[metric] = (totals[metric] ?? 0) + v;
              final dayVals = dailyMap.putIfAbsent(day, () => <String, double>{});
              dayVals[metric] = (dayVals[metric] ?? 0) + v;
            });
          });
        }

        perLocation.add(LocationInsight(
          title: m['location_title']?.toString() ?? '',
          totals: locTotals,
        ));
      }
    }

    final daily = dailyMap.entries
        .map((e) => DailyPoint(date: e.key, values: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return InsightsData(
      hasGoogle: j['has_google'] as bool? ?? false,
      error: j['error']?.toString(),
      locations: (j['locations'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(InsightLocation.fromJson)
          .toList(),
      totals: totals,
      daily: daily,
      perLocation: perLocation,
    );
  }

  final bool hasGoogle;
  final String? error;
  final List<InsightLocation> locations;
  final Map<String, double> totals;
  final List<DailyPoint> daily;
  final List<LocationInsight> perLocation;
}
