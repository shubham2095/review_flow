import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/models/whatsapp_models.dart';
import 'package:review_flow/screens/whatsapp_analytics_screen.dart';

WaMessageStats _stats({
  int sent = 0,
  int delivered = 0,
  int read = 0,
  int failed = 0,
  int inbound = 0,
  double deliveryRate = 0,
  double readRate = 0,
}) => WaMessageStats(
  days: const [],
  sent: sent,
  delivered: delivered,
  read: read,
  failed: failed,
  inbound: inbound,
  deliveryRate: deliveryRate,
  readRate: readRate,
);

void main() {
  group('funnelInsight', () {
    test('says so when nothing happened', () {
      expect(funnelInsight(_stats()), 'No messages in this period.');
    });

    test('gives delivered and read shares of sent, failures and inbound', () {
      final s = _stats(
        sent: 120,
        delivered: 115,
        read: 49,
        failed: 5,
        inbound: 1,
        deliveryRate: 95.8,
        readRate: 41,
      );
      expect(
        funnelInsight(s),
        '95.8% delivered and 41% read of 120 sent. 5 not delivered. '
        'Customers sent 1 message.',
      );
    });

    test('handles only inbound messages', () {
      expect(
        funnelInsight(_stats(inbound: 45)),
        'You sent no messages. Customers sent 45 messages.',
      );
    });
  });

  group('busiestDaySummary', () {
    final days = [
      WaDayStat(date: DateTime(2026, 11, 1), sent: 3, delivered: 3),
      WaDayStat(date: DateTime(2026, 11, 2), sent: 9, delivered: 8, read: 4),
      WaDayStat(date: DateTime(2026, 11, 3), sent: 9, delivered: 1),
    ];
    final series = [
      ChartSeries('Sent', Colors.grey, (d) => d.sent),
      ChartSeries('Read', Colors.green, (d) => d.read),
    ];

    test('names the first day with the highest first series', () {
      final text = busiestDaySummary(days, series)!;
      expect(text, startsWith('Busiest day '));
      expect(text, endsWith('Sent 9, Read 4'));
    });

    test('is null with no days or no data', () {
      expect(busiestDaySummary(const [], series), isNull);
      expect(
        busiestDaySummary([WaDayStat(date: DateTime(2026, 11, 1))], series),
        isNull,
      );
    });
  });
}
