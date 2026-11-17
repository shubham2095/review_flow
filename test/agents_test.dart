import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/agents_models.dart';
import 'package:review_flow/screens/agents_screen.dart';
import 'package:review_flow/theme/brand.dart';

void main() {
  group('models', () {
    test('WaAgent reads the roster row', () {
      final a = WaAgent.fromJson({
        'id': 'u1',
        'name': 'Asha Rao',
        'email': 'asha@example.com',
        'avatar_url': null,
        'roles': ['agent'],
        'active_conversations_count': 3,
        'total_handled': 41,
      });
      expect(a.name, 'Asha Rao');
      expect(a.roleLabel, 'Agent');
      expect(a.activeChats, 3);
      expect(a.totalHandled, 41);
      expect(a.avatarUrl, '');
    });

    test('a missing role gives an empty label', () {
      expect(
        WaAgent.fromJson({'id': '1', 'name': 'A', 'email': ''}).roleLabel,
        '',
      );
    });

    test('WaAgentDetail reads the chats and falls back to the number', () {
      final d = WaAgentDetail.fromJson({
        'agent': {
          'id': 'u1',
          'name': 'Asha',
          'email': 'a@b.c',
          'conversations': [
            {
              'id': 'c1',
              'contact_name': null,
              'contact_phone': '+919876543210',
              'status': 'open',
              'last_message_at': '2026-11-16T10:00:00Z',
            },
          ],
        },
      });
      expect(d.chats, hasLength(1));
      expect(d.chats.first.title, '+919876543210');
      expect(d.chats.first.lastMessageAt, isNotNull);
    });

    test('WaAgentStat and WaAssignable', () {
      final s = WaAgentStat.fromJson({
        'id': 'u1',
        'open': 2,
        'pending': 1,
        'resolved': 5,
        'closed': 0,
        'total': 8,
      });
      expect(s.total, 8);
      final p = WaAssignable.fromJson({
        'id': 'u1',
        'name': 'Asha',
        'is_me': true,
      });
      expect(p.isMe, isTrue);
    });
  });

  group('helpers', () {
    test('agentWorkloadLine is singular and plural', () {
      expect(
        agentWorkloadLine(
          const WaAgent(
            id: '1',
            name: 'A',
            email: '',
            activeChats: 1,
            totalHandled: 9,
          ),
        ),
        '1 active chat · 9 handled',
      );
      expect(
        agentWorkloadLine(const WaAgent(id: '1', name: 'A', email: '')),
        '0 active chats · 0 handled',
      );
    });

    test('agentChatStatus words and colours', () {
      expect(agentChatStatus('open').$1, 'Open');
      expect(agentChatStatus('resolved').$2, good);
      expect(agentChatStatus('pending').$1, 'Pending');
      expect(agentChatStatus('weird').$1, 'Weird');
      expect(agentChatStatus('').$1, '—');
    });
  });
}
