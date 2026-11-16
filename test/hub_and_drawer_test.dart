import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:review_flow/screens/product_hub.dart';
import 'package:review_flow/screens/wa_destinations.dart';
import 'package:review_flow/services/products.dart';
import 'package:review_flow/widgets/app_drawer.dart';

import 'test_helpers.dart';

void main() {
  test('hubGreeting follows the hour', () {
    expect(hubGreeting(6), 'Good morning');
    expect(hubGreeting(11), 'Good morning');
    expect(hubGreeting(12), 'Good afternoon');
    expect(hubGreeting(16), 'Good afternoon');
    expect(hubGreeting(17), 'Good evening');
    expect(hubGreeting(23), 'Good evening');
  });

  test('every product box has highlights', () {
    for (final p in Product.values) {
      expect(hubHighlights[p], isNotEmpty, reason: p.name);
    }
  });

  group('WhatsApp drawer places', () {
    test('every place except More is listed exactly once', () {
      final listed = [for (final g in waDrawerGroups) ...g.$2];
      expect(listed.toSet().length, listed.length);
      expect(
        listed.toSet(),
        WaDestination.values.where((d) => d != WaDestination.more).toSet(),
      );
    });

    test('only the four main tabs are tabs', () {
      expect(
        WaDestination.values.where((d) => d.isTab).toList(),
        [
          WaDestination.home,
          WaDestination.inbox,
          WaDestination.contacts,
          WaDestination.campaigns,
        ],
      );
    });
  });

  group('AppDrawer for WhatsApp', () {
    Future<void> openDrawer(
      WidgetTester tester, {
      required ValueNotifier<WaDestination> current,
      required ValueNotifier<int> unread,
      required void Function(WaDestination) onWhatsApp,
    }) async {
      ignoreFontErrors();
      PackageInfo.setMockInitialValues(
        appName: 'Eydia',
        packageName: 'com.heltog.review_flow',
        version: '2.1.0',
        buildNumber: '1',
        buildSignature: '',
      );
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: key,
            drawer: AppDrawer(
              name: 'Jay',
              email: 'jay@example.com',
              selectedIndex: 9,
              onSelect: (_) {},
              onLogout: () {},
              product: Product.whatsapp,
              onHub: () {},
              waCurrent: current,
              waUnread: unread,
              onWhatsApp: onWhatsApp,
            ),
            body: const SizedBox(),
          ),
        ),
      );
      key.currentState!.openDrawer();
      await tester.pumpAndSettle();
    }

    testWidgets('lists every WhatsApp place and shows unread on Inbox', (
      tester,
    ) async {
      await openDrawer(
        tester,
        current: ValueNotifier(WaDestination.inbox),
        unread: ValueNotifier(7),
        onWhatsApp: (_) {},
      );
      for (final g in waDrawerGroups) {
        for (final d in g.$2) {
          expect(find.text(d.label), findsOneWidget, reason: d.name);
        }
      }
      expect(find.text('7'), findsOneWidget);
      // The GBP pages are not listed in WhatsApp.
      expect(find.text('Reviews'), findsNothing);
      expectNoRealErrors(tester);
    });

    testWidgets('tapping a place reports it and closes the drawer', (
      tester,
    ) async {
      WaDestination? opened;
      await openDrawer(
        tester,
        current: ValueNotifier(WaDestination.home),
        unread: ValueNotifier(0),
        onWhatsApp: (d) => opened = d,
      );
      await tester.ensureVisible(find.text('Analytics'));
      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();
      expect(opened, WaDestination.analytics);
      expect(find.text('Analytics'), findsNothing);
      expectNoRealErrors(tester);
    });
  });
}
