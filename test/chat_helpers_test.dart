import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/whatsapp_chat_screen.dart';
import 'package:review_flow/services/wa_drafts.dart';
import 'package:review_flow/widgets/linkified_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  group('chatWindowLabel', () {
    final now = DateTime(2026, 11, 20, 12);

    test('open with hours left', () {
      final until = now.add(const Duration(hours: 3, minutes: 20));
      expect(chatWindowLabel(until, true, now), 'Can reply · 3h 20m left');
    });

    test('open with under an hour left', () {
      final until = now.add(const Duration(minutes: 12, seconds: 30));
      expect(chatWindowLabel(until, true, now), 'Can reply · 12m left');
    });

    test('open with seconds left', () {
      final until = now.add(const Duration(seconds: 20));
      expect(
        chatWindowLabel(until, true, now),
        'Can reply · less than a minute left',
      );
    });

    test('open without an end time', () {
      expect(chatWindowLabel(null, true, now), 'Can reply');
    });

    test('closed, or already expired', () {
      expect(chatWindowLabel(null, false, now), 'Reply window closed');
      expect(
        chatWindowLabel(now.subtract(const Duration(minutes: 1)), true, now),
        'Reply window closed',
      );
    });
  });

  group('splitLinks', () {
    test('plain text stays one piece', () {
      final parts = splitLinks('Thanks, see you tomorrow');
      expect(parts.length, 1);
      expect(parts.single.kind, LinkKind.text);
    });

    test('finds a web link and keeps the sentence punctuation out of it', () {
      final parts = splitLinks('Visit https://eydia.in/plans. Thanks!');
      final link = parts.firstWhere((p) => p.kind == LinkKind.url);
      expect(link.text, 'https://eydia.in/plans');
      expect(link.target, 'https://eydia.in/plans');
      expect(
        parts.map((p) => p.text).join(),
        'Visit https://eydia.in/plans. Thanks!',
      );
    });

    test('www links get https in front', () {
      final link = splitLinks(
        'go to www.eydia.in now',
      ).firstWhere((p) => p.kind == LinkKind.url);
      expect(link.target, 'https://www.eydia.in');
    });

    test('finds phone numbers of 8 to 15 digits', () {
      final phone = splitLinks(
        'Call +91 98765 43210 today',
      ).firstWhere((p) => p.kind == LinkKind.phone);
      expect(phone.text, '+91 98765 43210');
      expect(phone.target, 'tel:+919876543210');
    });

    test('short numbers (order ids, prices) are not phone links', () {
      expect(
        splitLinks(
          'Order 12345 costs 999',
        ).every((p) => p.kind == LinkKind.text),
        isTrue,
      );
    });

    test('pieces always join back to the original text', () {
      const text = 'a https://x.in/y, b +919876543210 c www.z.com).';
      expect(splitLinks(text).map((p) => p.text).join(), text);
    });
  });

  testWidgets('LinkifiedText shows the whole message', (tester) async {
    ignoreFontErrors();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LinkifiedText(
            'Pay at https://eydia.in or call +919876543210',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    expect(
      rich.text.toPlainText(),
      'Pay at https://eydia.in or call +919876543210',
    );
    expectNoRealErrors(tester);
  });

  group('WaDrafts', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves, reads and clears a draft per chat', () async {
      await WaDrafts.save('u1', 'chatA', 'hello there');
      expect(await WaDrafts.read('u1', 'chatA'), 'hello there');
      expect(await WaDrafts.read('u1', 'chatB'), isNull);
      await WaDrafts.clear('u1', 'chatA');
      expect(await WaDrafts.read('u1', 'chatA'), isNull);
    });

    test('another account never sees the draft', () async {
      await WaDrafts.save('u1', 'chatA', 'private');
      expect(await WaDrafts.read('u2', 'chatA'), isNull);
    });

    test('empty text removes the draft; no user id means no drafts', () async {
      await WaDrafts.save('u1', 'chatA', 'something');
      await WaDrafts.save('u1', 'chatA', '   ');
      expect(await WaDrafts.read('u1', 'chatA'), isNull);
      await WaDrafts.save('', 'chatA', 'ignored');
      expect(await WaDrafts.read('', 'chatA'), isNull);
    });

    test(
      'prune drops drafts older than 30 days and keeps the newest 50',
      () async {
        await WaDrafts.save('u1', 'old', 'stale');
        await WaDrafts.save('u1', 'fresh', 'recent');
        // 31 days later only the draft saved "now" would still count, so move the
        // clock forward for the old one by pruning with a later "now".
        final later = DateTime.now().add(const Duration(days: 31));
        await WaDrafts.prune(now: later);
        expect(await WaDrafts.read('u1', 'old'), isNull);
        expect(await WaDrafts.read('u1', 'fresh'), isNull);

        for (var i = 0; i < 55; i++) {
          await WaDrafts.save('u1', 'c$i', 'draft $i');
        }
        await WaDrafts.prune();
        var left = 0;
        for (var i = 0; i < 55; i++) {
          if (await WaDrafts.read('u1', 'c$i') != null) left++;
        }
        expect(left, 50);
      },
    );
  });
}
