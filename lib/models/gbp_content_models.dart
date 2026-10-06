int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) => v?.toString();

class GbpPostItem {
  GbpPostItem.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        type = _s(j['type']) ?? 'UPDATE',
        body = _s(j['body']) ?? '',
        status = _s(j['status']) ?? 'DRAFT',
        ctaUrl = _s(j['cta_url']),
        locationTitle = _s(j['location_title']) ?? '',
        clientName = _s(j['client_name']) ?? '',
        imageUrl = _s(j['image_url']),
        publishedAt = _s(j['published_at']),
        createdAt = _s(j['created_at']);

  final int id;
  final String type;
  final String body;
  final String status;
  final String? ctaUrl;
  final String locationTitle;
  final String clientName;
  final String? imageUrl;
  final String? publishedAt;
  final String? createdAt;

  String get dateLabel {
    final t = publishedAt ?? createdAt ?? '';
    return t.length >= 10 ? t.substring(0, 10) : '';
  }
}

class GbpPhotoItem {
  GbpPhotoItem.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        caption = _s(j['caption']) ?? '',
        status = _s(j['status']) ?? 'DRAFT',
        locationTitle = _s(j['location_title']) ?? '',
        clientName = _s(j['client_name']) ?? '',
        imageUrl = _s(j['image_url']) ?? '',
        createdAt = _s(j['created_at']);

  final int id;
  final String caption;
  final String status;
  final String locationTitle;
  final String clientName;
  final String imageUrl;
  final String? createdAt;
}

class GbpContentBoard {
  GbpContentBoard({required this.posts, required this.photos});

  factory GbpContentBoard.fromJson(Map<String, dynamic> j) {
    return GbpContentBoard(
      posts: ((j['posts'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(GbpPostItem.fromJson)
          .toList(),
      photos: ((j['photos'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(GbpPhotoItem.fromJson)
          .toList(),
    );
  }

  final List<GbpPostItem> posts;
  final List<GbpPhotoItem> photos;
}

class LocationOption {
  LocationOption.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        title = _s(j['title']) ?? '';

  final int id;
  final String title;
}

const postTypeLabels = {
  'UPDATE': 'Update',
  'OFFER': 'Offer',
  'EVENT': 'Event',
};

const postTypeEmoji = {
  'UPDATE': '📢',
  'OFFER': '🏷️',
  'EVENT': '🎉',
};
