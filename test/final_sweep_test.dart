import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:review_flow/screens/home_shell.dart';
import 'package:review_flow/screens/pages.dart';
import 'package:review_flow/services/products.dart';
import 'package:review_flow/services/session.dart';
import 'package:review_flow/widgets/app_drawer.dart';

import 'test_helpers.dart';

AppUser _user({List<String>? permissions, List<String>? features}) => AppUser(
  id: '1',
  name: 'Jay Kushwah',
  email: 'jay.kushwah.long.address@example.com',
  planFeatures: features,
  permissions: permissions,
);

Future<void> _openDrawer(
  WidgetTester tester, {
  required Product product,
  required AppUser user,
  double textScale = 1,
}) async {
  ignoreFontErrors();
  PackageInfo.setMockInitialValues(
    appName: 'Eydia',
    packageName: 'com.heltog.review_flow',
    version: '2.1.0',
    buildNumber: '1',
    buildSignature: '',
  );
  // Tall enough that every row is built, so an overflow anywhere shows up.
  tester.view.physicalSize = const Size(360, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey<ScaffoldState>();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        key: key,
        drawer: AppDrawer(
          name: user.name,
          email: user.email,
          selectedIndex: product == Product.whatsapp ? kPageWhatsApp : 0,
          onSelect: (_) {},
          onLogout: () {},
          product: product,
          onHub: () {},
          user: user,
        ),
        body: const SizedBox(),
      ),
    ),
  );
  key.currentState!.openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  group('page indexes', () {
    test('every page constant is unique and has a title', () {
      final pages = [
        kPageOverview,
        kPageReviews,
        kPagePosts,
        kPageInsights,
        kPageAiTools,
        kPageBusinessProfile,
        kPageAutomation,
        kPageBilling,
        kPageAccount,
        kPageWhatsApp,
        kPageTeam,
        kPageSeo,
        kPageAiStudio,
        kPageInvoicing,
      ];
      expect(pages.toSet().length, pages.length);
      // Contiguous from 0, so a page index is also a list index.
      expect([...pages]..sort(), List.generate(pages.length, (i) => i));
      expect(HomeShell.pageTitles.length, pages.length);
    });

    test('titles sit at the right index', () {
      final t = HomeShell.pageTitles;
      expect(t[kPageOverview], 'Overview');
      expect(t[kPageBilling], 'Plans & billing');
      expect(t[kPageWhatsApp], 'WhatsApp');
      expect(t[kPageTeam], 'Team');
      expect(t[kPageSeo], 'SEO');
      expect(t[kPageAiStudio], 'AI Studio');
      expect(t[kPageInvoicing], 'Invoicing');
    });
  });

  group('drawer lists every module', () {
    testWidgets('Google Business Profile, owner with everything', (
      tester,
    ) async {
      await _openDrawer(tester, product: Product.gbp, user: _user());
      for (final label in [
        'All products',
        'Overview',
        'Reviews',
        'Posts & Photos',
        'Insights',
        'AI Tools',
        'Business profile',
        'Automation',
        'SEO',
        'AI Studio',
        'Team',
        'Invoicing',
        'Plans & billing',
        'My Profile',
        'Logout',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // No WhatsApp places in the Google drawer.
      expect(find.text('Inbox'), findsNothing);
      expectNoRealErrors(tester);
    });

    testWidgets('WhatsApp, owner with everything', (tester) async {
      await _openDrawer(tester, product: Product.whatsapp, user: _user());
      for (final label in [
        'Home',
        'Inbox',
        'Contacts',
        'Campaigns',
        'Templates',
        'Chatbots & automations',
        'Agents',
        'Analytics',
        'Numbers',
        'Blocked numbers',
        'Team',
        'Invoicing',
        'Plans & billing',
        'My Profile',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // No Google pages in the WhatsApp drawer.
      expect(find.text('SEO'), findsNothing);
      expect(find.text('AI Studio'), findsNothing);
      expectNoRealErrors(tester);
    });
  });

  group('drawer at 1.5x text on a small phone', () {
    testWidgets('Google Business Profile', (tester) async {
      await _openDrawer(
        tester,
        product: Product.gbp,
        user: _user(),
        textScale: 1.5,
      );
      expectNoRealErrors(tester);
    });

    testWidgets('WhatsApp', (tester) async {
      await _openDrawer(
        tester,
        product: Product.whatsapp,
        user: _user(),
        textScale: 1.5,
      );
      expectNoRealErrors(tester);
    });
  });

  group('a restricted team member', () {
    testWidgets('with only Inbox sees no owner tools in WhatsApp', (
      tester,
    ) async {
      await _openDrawer(
        tester,
        product: Product.whatsapp,
        user: _user(permissions: ['conversations.view']),
      );
      expect(find.text('Inbox'), findsOneWidget);
      for (final hidden in [
        'Contacts',
        'Campaigns',
        'Templates',
        'Agents',
        'Analytics',
        'Numbers',
        'Team',
        'Plans & billing',
      ]) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
      expectNoRealErrors(tester);
    });

    testWidgets('on a plan without SEO or Invoicing, those are hidden', (
      tester,
    ) async {
      await _openDrawer(
        tester,
        product: Product.gbp,
        user: _user(features: ['dash_gbp']),
      );
      expect(find.text('SEO'), findsNothing);
      expect(find.text('Invoicing'), findsNothing);
      // Always-on Google pages stay.
      expect(find.text('AI Studio'), findsOneWidget);
      expect(find.text('Reviews'), findsOneWidget);
      expectNoRealErrors(tester);
    });
  });
}
