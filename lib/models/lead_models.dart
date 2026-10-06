import 'package:flutter/material.dart';

int _i(dynamic v) => num.tryParse((v)?.toString() ?? '')?.toInt() ?? 0;

String? _s(dynamic v) => v?.toString();

class LeadItem {
  LeadItem.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']) ?? '',
        email = _s(j['email']),
        phone = _s(j['phone']),
        source = _s(j['source']) ?? 'WEBSITE',
        stage = _s(j['stage']) ?? 'NEW',
        notes = _s(j['notes']),
        clientName = _s(j['client_name']),
        clientId = _i(j['client_id']),
        createdAt = _s(j['created_at']);

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String source;
  final String stage;
  final String? notes;
  final String? clientName;
  final int clientId;
  final String? createdAt;

  String get dateLabel {
    final t = createdAt ?? '';
    return t.length >= 10 ? t.substring(0, 10) : '';
  }
}

class ClientOption {
  ClientOption.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']) ?? '';

  final int id;
  final String name;
}

class LeadBoard {
  LeadBoard({required this.leads, required this.clients, required this.stages});

  factory LeadBoard.fromJson(Map<String, dynamic> j) {
    return LeadBoard(
      leads: (j['leads'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(LeadItem.fromJson)
          .toList(),
      clients: (j['clients'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ClientOption.fromJson)
          .toList(),
      stages: (j['stages'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  final List<LeadItem> leads;
  final List<ClientOption> clients;
  final List<String> stages;
}

const stageLabels = {
  'NEW': 'New leads',
  'CONTACTED': 'Contacted',
  'FOLLOW_UP': 'Follow up',
  'APPOINTMENT': 'Appointment',
  'CONVERTED': 'Converted',
  'LOST': 'Lost',
};

const stageEmoji = {
  'NEW': '🆕',
  'CONTACTED': '📞',
  'FOLLOW_UP': '🔁',
  'APPOINTMENT': '📅',
  'CONVERTED': '🎉',
  'LOST': '❌',
};

const stageColors = {
  'NEW': Color(0xFF4C6FFF),
  'CONTACTED': Color(0xFF0EA5E9),
  'FOLLOW_UP': Color(0xFFF59E0B),
  'APPOINTMENT': Color(0xFF8B5CF6),
  'CONVERTED': Color(0xFF22C55E),
  'LOST': Color(0xFFEF4444),
};

const sourceLabels = {
  'FACEBOOK': 'Facebook',
  'INSTAGRAM': 'Instagram',
  'WEBSITE': 'Website',
  'WHATSAPP': 'WhatsApp',
  'GOOGLE_FORM': 'Google Form',
};
