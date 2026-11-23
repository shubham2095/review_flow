import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/whatsapp_models.dart';
import 'package:review_flow/screens/whatsapp_bulk_create_screen.dart';
import 'package:review_flow/screens/whatsapp_bulk_detail_screen.dart';
import 'package:review_flow/screens/whatsapp_campaign_detail_screen.dart';
import 'package:review_flow/theme/brand.dart';
import 'package:review_flow/widgets/wa_ui.dart';

import 'test_helpers.dart';

WaCampaign _campaign(
  String status, {
  int total = 100,
  int sent = 0,
  int failed = 0,
}) => WaCampaign.fromJson({
  'id': 'c1',
  'name': 'Diwali',
  'status': status,
  'total_recipients': total,
  'sent_count': sent,
  'failed_count': failed,
});

WaBulkSend _bulk(
  String status, {
  int total = 10,
  int sent = 0,
  int failed = 0,
}) => WaBulkSend.fromJson({
  'uuid': 'b1',
  'template_name': 'order_update',
  'status': status,
  'total': total,
  'sent_count': sent,
  'failed_count': failed,
});

void main() {
  group('parseBulkNumbers', () {
    test('keeps 10 to 15 digit numbers once, in order, digits only', () {
      final r = parseBulkNumbers('+91 98765 43210\n919812345678, 919812345678');
      expect(r.valid, ['919876543210', '919812345678']);
      expect(r.duplicates, 1);
      expect(r.rejected, 0);
    });

    test('counts entries that are too short or too long', () {
      final r = parseBulkNumbers('12345\n9198765432101234567\n919876543210');
      expect(r.valid, ['919876543210']);
      expect(r.rejected, 2);
    });

    test('blank lines are ignored; ten-digit numbers are counted', () {
      final r = parseBulkNumbers('\n\n9876543210;  ');
      expect(r.valid, ['9876543210']);
      expect(r.tenDigit, 1);
      expect(r.rejected, 0);
    });
  });

  group('addCountryCode', () {
    test('adds 91 only to entries that are exactly 10 digits', () {
      final out = addCountryCode('9876543210\n919812345678\n98 76 54 32 10');
      expect(out.split('\n'), ['919876543210', '919812345678', '919876543210']);
    });

    test('leaves other entries exactly as typed', () {
      expect(addCountryCode('abc\n12345'), 'abc\n12345');
    });
  });

  group('removeBulkNumber', () {
    test('removes every entry with those digits and keeps the rest', () {
      final out = removeBulkNumber(
        '+91 98765 43210\n919812345678\n919876543210',
        '919876543210',
      );
      expect(out, '919812345678');
    });
  });

  group('stories', () {
    test('campaign story says where it stands', () {
      expect(
        campaignStory(_campaign('draft')),
        contains('Nothing has been sent'),
      );
      expect(
        campaignStory(_campaign('running', sent: 30, failed: 5)),
        contains('35 of 100 handled'),
      );
      expect(
        campaignStory(_campaign('paused', sent: 20)),
        contains('cannot resume'),
      );
      expect(
        campaignStory(_campaign('completed', sent: 95, failed: 5)),
        contains('95 of 100 went out, 5 could not be sent'),
      );
      expect(
        campaignStory(_campaign('completed', sent: 100)),
        'Done. All 100 were sent.',
      );
      expect(
        campaignStory(_campaign('cancelled', sent: 10)),
        contains('Cancelled after 10 of 100'),
      );
    });

    test('bulk story says sending, done, or done with failures', () {
      expect(
        bulkStory(_bulk('processing', sent: 3)),
        contains('3 of 10 handled'),
      );
      expect(
        bulkStory(_bulk('completed', sent: 10)),
        'Done. All 10 were sent.',
      );
      expect(
        bulkStory(_bulk('completed', sent: 7, failed: 3)),
        contains('7 of 10 went out, 3 failed'),
      );
    });
  });

  group('shared bars', () {
    testWidgets('StackedBar reads out its slices and what is waiting', (
      tester,
    ) async {
      ignoreFontErrors();
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StackedBar(
              total: 100,
              segments: [
                BarSegment('Read', 20, good),
                BarSegment('Delivered', 30, brand),
                BarSegment('Failed', 0, bad),
              ],
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Read 20, Delivered 30, Waiting 50, out of 100'),
        findsOneWidget,
      );
      // A slice with no value is left out of the legend.
      expect(find.text('Failed 0'), findsNothing);
      expect(find.text('Read 20'), findsOneWidget);
      expectNoRealErrors(tester);
      handle.dispose();
    });

    testWidgets('AppProgress is read out as text', (tester) async {
      ignoreFontErrors();
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppProgress(value: 0.4, label: '120 of 300 handled'),
          ),
        ),
      );
      expect(find.bySemanticsLabel('120 of 300 handled'), findsOneWidget);
      expectNoRealErrors(tester);
      handle.dispose();
    });
  });
}
