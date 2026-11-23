import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/whatsapp_models.dart';
import 'package:review_flow/screens/whatsapp_chatbot_screen.dart';
import 'package:review_flow/screens/whatsapp_workflow_screen.dart';

WaChatRule _rule(
  String keyword, {
  String match = 'contains',
  int priority = 0,
  bool active = true,
  String reply = 'Hello',
  String type = 'text',
  String template = '',
}) => WaChatRule.fromJson({
  'id': keyword,
  'keyword': keyword,
  'match_type': match,
  'priority': priority,
  'is_active': active,
  'response_type': type,
  'response_text': reply,
  'template_name': template,
});

void main() {
  group('ruleSentence and ruleReplyLine', () {
    test('read as sentences', () {
      expect(ruleSentence(_rule('price')), 'When a message contains "price"');
      expect(
        ruleSentence(_rule('hi', match: 'exact')),
        'When a message is exactly "hi"',
      );
      expect(
        ruleSentence(_rule('hi', match: 'starts_with')),
        'When a message starts with "hi"',
      );
      expect(
        ruleSentence(_rule('a.*', match: 'regex')),
        'When a message matches the pattern "a.*"',
      );
    });

    test('reply line says text or template', () {
      expect(ruleReplyLine(_rule('x', reply: 'Hi')), 'Replies: Hi');
      expect(
        ruleReplyLine(_rule('x', type: 'template', template: 'welcome')),
        'Sends the template welcome',
      );
    });
  });

  group('ruleMatches', () {
    test('ignores case and surrounding spaces', () {
      expect(ruleMatches(_rule('price'), '  What is the PRICE? '), isTrue);
      expect(ruleMatches(_rule('hi', match: 'exact'), 'HI'), isTrue);
      expect(ruleMatches(_rule('hi', match: 'exact'), 'hi there'), isFalse);
      expect(
        ruleMatches(_rule('hi', match: 'starts_with'), 'Hi there'),
        isTrue,
      );
      expect(ruleMatches(_rule('hi', match: 'starts_with'), 'oh hi'), isFalse);
    });

    test('regex works and a broken pattern simply does not match', () {
      expect(ruleMatches(_rule(r'\d{3}', match: 'regex'), 'room 204'), isTrue);
      expect(ruleMatches(_rule('(', match: 'regex'), 'anything'), isFalse);
    });

    test('empty message or keyword never matches', () {
      expect(ruleMatches(_rule('price'), '   '), isFalse);
      expect(ruleMatches(_rule(' '), 'price'), isFalse);
    });
  });

  group('firstMatchingRule', () {
    test('lower order number wins, then list order', () {
      final rules = [
        _rule('price', priority: 5, reply: 'late'),
        _rule('price', priority: 1, reply: 'early'),
        _rule('price', priority: 1, reply: 'second'),
      ];
      expect(firstMatchingRule(rules, 'price?')!.responseText, 'early');
    });

    test('skips switched-off rules and returns null with no match', () {
      final rules = [_rule('price', active: false)];
      expect(firstMatchingRule(rules, 'price'), isNull);
      expect(firstMatchingRule([_rule('cost')], 'price'), isNull);
    });
  });

  test('executionStatusLabel tidies the status', () {
    expect(executionStatusLabel('completed'), 'Completed');
    expect(executionStatusLabel('waiting_reply'), 'Waiting reply');
    expect(executionStatusLabel(''), '—');
  });
}
