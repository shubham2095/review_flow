int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

String? _s(dynamic v) => v?.toString();

class SocialPostItem {
  SocialPostItem.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        platform = _s(j['platform']) ?? 'FACEBOOK',
        body = _s(j['body']) ?? '',
        status = _s(j['status']) ?? 'DRAFT',
        error = _s(j['error']),
        scheduledAt = _s(j['scheduled_at']),
        clientName = _s(j['client_name']),
        createdAt = _s(j['created_at']);

  final int id;
  final String platform;
  final String body;
  final String status;
  final String? error;
  final String? scheduledAt;
  final String? clientName;
  final String? createdAt;

  String get dateLabel {
    final t = scheduledAt ?? createdAt ?? '';
    return t.length >= 16 ? t.substring(0, 16).replaceFirst('T', ' ') : '';
  }
}

class SocialClientOption {
  SocialClientOption.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']) ?? '';

  final int id;
  final String name;
}

class SocialBoard {
  SocialBoard({required this.posts, required this.clients, required this.metaConnected});

  factory SocialBoard.fromJson(Map<String, dynamic> j) {
    return SocialBoard(
      posts: (j['posts'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(SocialPostItem.fromJson)
          .toList(),
      clients: (j['clients'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(SocialClientOption.fromJson)
          .toList(),
      metaConnected: j['meta_connected'] as bool? ?? false,
    );
  }

  final List<SocialPostItem> posts;
  final List<SocialClientOption> clients;
  final bool metaConnected;
}

const platformLabels = {
  'FACEBOOK': 'Facebook',
  'INSTAGRAM': 'Instagram',
  'LINKEDIN': 'LinkedIn',
  'X': 'X',
};

const platformEmoji = {
  'FACEBOOK': '📘',
  'INSTAGRAM': '📸',
  'LINKEDIN': '💼',
  'X': '🐦',
};

const platformCharLimit = {
  'FACEBOOK': 63206,
  'INSTAGRAM': 2200,
  'LINKEDIN': 3000,
  'X': 280,
};

const statusLabels = {
  'PUBLISHED': 'Published',
  'SCHEDULED': 'Scheduled',
  'DRAFT': 'Draft',
  'FAILED': 'Failed',
};
