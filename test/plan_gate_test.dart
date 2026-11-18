import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/plan_gate_screen.dart';
import 'package:review_flow/services/platform_rules.dart';
import 'package:review_flow/services/products.dart';
import 'package:review_flow/services/session.dart';

import 'test_helpers.dart';

Future<void> _pump(WidgetTester tester, {Product? product}) async {
  ignoreFontErrors();
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Session.setFromPayload({
    'id': '1',
    'name': 'Shubham Sharma',
    'email': 's@example.com',
    'subscription': {'status': 'active', 'plan_name': 'GMB PLAN'},
    'plan_features': ['dash_gbp'],
  });
  addTearDown(Session.clear);
  await tester.pumpWidget(
    MaterialApp(
      home: PlanGateScreen(
        product: product,
        onUnlocked: () {},
        onSignedOut: () {},
        onBack: () {},
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('wording', () {
    test('a product the plan lacks says "Unlock"', () {
      final h = planGateHeadline(Product.gbp, true);
      expect(h.title, 'Unlock Google Business');
      expect(h.subtitle, contains('not included in your current plan'));
    });

    test('no plan at all says "Activate your workspace"', () {
      final h = planGateHeadline(null, false);
      expect(h.title, 'Activate your workspace');
      // A product tapped by someone with no plan is the same page.
      expect(planGateHeadline(Product.whatsapp, false).title, h.title);
    });

    test('three steps, named after the product when there is one', () {
      final steps = planGateSteps(Product.whatsapp);
      expect(steps, hasLength(3));
      expect(steps[1].text, contains('WhatsApp'));
      expect(planGateSteps(null)[1].text, contains('suits your business'));
    });
  });

  test('only iOS is kept from offering the purchase link', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(planPurchaseLinkAllowed, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(planPurchaseLinkAllowed, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android: a locked product offers the website button', (
    tester,
  ) async {
    // The override must be cleared before the test body ends.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pump(tester, product: Product.whatsapp);

      expect(find.text('Unlock WhatsApp'), findsOneWidget);
      expect(find.text('Your plan: GMB PLAN'), findsOneWidget);
      expect(find.text('How to get it'), findsOneWidget);
      expect(find.text('Choose a plan'), findsOneWidget);
      expect(find.text('Get a plan on the website'), findsOneWidget);
      expect(find.text('Check again'), findsOneWidget);
      expectNoRealErrors(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS: no purchase button, neutral wording', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await _pump(tester, product: Product.whatsapp);

      expect(find.text('Unlock WhatsApp'), findsOneWidget);
      expect(find.text('To switch it on'), findsOneWidget);
      expect(find.text('Get a plan on the website'), findsNothing);
      expect(find.text('Choose a plan'), findsNothing);
      expect(find.text('Check again'), findsOneWidget);
      expectNoRealErrors(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
