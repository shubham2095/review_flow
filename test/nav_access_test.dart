import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:review_flow/screens/wa_destinations.dart';
import 'package:review_flow/services/nav_access.dart';
import 'package:review_flow/services/products.dart';
import 'package:review_flow/services/session.dart';
import 'package:review_flow/widgets/app_drawer.dart';

import 'test_helpers.dart';

AppUser _user({
  List<String>? permissions,
  List<String>? features,
  bool superAdmin = false,
}) => AppUser(
  id: '1',
  name: 'Jay',
  email: 'jay@example.com',
  isSuperAdmin: superAdmin,
  planFeatures: features,
  permissions: permissions,
);

void main() {
  group('AppUser.fromJson', () {
    test('reads permissions and roles', () {
      final u = AppUser.fromJson({
        'id': '1',
        'name': 'A',
        'email': 'a@b.c',
        'permissions': ['contacts.view', 'conversations.view'],
        'roles': ['agent'],
      });
      expect(u.permissions, ['contacts.view', 'conversations.view']);
      expect(u.roles, ['agent']);
    });

    test('a missing list stays null so nothing is hidden', () {
      final u = AppUser.fromJson({'id': '1', 'name': 'A', 'email': 'a@b.c'});
      expect(u.permissions, isNull);
      expect(u.roles, isEmpty);
    });
  });

  group('navAllowed', () {
    const inbox = NavRule(perm: 'conversations.view');
    const analytics = NavRule(perm: 'analytics.view', feature: 'reports');

    test('no user sees nothing, a super admin sees everything', () {
      expect(navAllowed(null, inbox), isFalse);
      expect(navAllowed(_user(superAdmin: true, permissions: []), analytics), isTrue);
    });

    test('a permission is needed only when the server sent the list', () {
      expect(navAllowed(_user(permissions: ['contacts.view']), inbox), isFalse);
      expect(
        navAllowed(_user(permissions: ['conversations.view']), inbox),
        isTrue,
      );
      expect(navAllowed(_user(), inbox), isTrue);
    });

    test('a plan feature is needed only when the plan has a feature list', () {
      final perms = ['analytics.view'];
      expect(
        navAllowed(_user(permissions: perms, features: ['chatbot']), analytics),
        isFalse,
      );
      expect(
        navAllowed(_user(permissions: perms, features: ['reports']), analytics),
        isTrue,
      );
      expect(navAllowed(_user(permissions: perms), analytics), isTrue);
    });

    test('an entry with no rule is open to every signed-in person', () {
      expect(navAllowedAny(_user(permissions: []), const []), isTrue);
    });

    test('any one matching rule is enough', () {
      const rules = [
        NavRule(perm: 'bots.view', feature: 'chatbot'),
        NavRule(perm: 'workflows.view', feature: 'automations'),
      ];
      expect(
        navAllowedAny(
          _user(permissions: ['workflows.view'], features: ['automations']),
          rules,
        ),
        isTrue,
      );
      expect(
        navAllowedAny(_user(permissions: ['workflows.view'], features: []), rules),
        isFalse,
      );
    });
  });

  group('WaDestination.allows', () {
    test('an agent with only Inbox ticked sees Home and Inbox', () {
      final agent = _user(permissions: ['conversations.view']);
      final seen = WaDestination.values.where((d) => d.allows(agent)).toSet();
      expect(seen, {
        WaDestination.home,
        WaDestination.inbox,
        WaDestination.more,
      });
    });

    test('an owner with every permission sees every place', () {
      final owner = _user(
        permissions: [
          'conversations.view',
          'contacts.view',
          'campaigns.view',
          'templates.view',
          'bots.view',
          'workflows.view',
          'analytics.view',
          'whatsapp.view',
        ],
        features: ['chatbot', 'automations', 'reports'],
      );
      expect(WaDestination.values.every((d) => d.allows(owner)), isTrue);
    });
  });

  group('AppDrawer for a restricted agent', () {
    testWidgets('lists only what was ticked and hides Plans & billing', (
      tester,
    ) async {
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
              name: 'Agent',
              email: 'agent@example.com',
              selectedIndex: 9,
              onSelect: (_) {},
              onLogout: () {},
              product: Product.whatsapp,
              onHub: () {},
              user: _user(permissions: ['conversations.view']),
            ),
            body: const SizedBox(),
          ),
        ),
      );
      key.currentState!.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      for (final hidden in [
        'Contacts',
        'Campaigns',
        'Templates',
        'Analytics',
        'Numbers',
        'Blocked numbers',
        'Plans & billing',
      ]) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
      // Groups with nothing in them are not shown.
      expect(find.text('MESSAGING'), findsNothing);
      expect(find.text('RESULTS'), findsNothing);
      expect(find.text('SETUP'), findsNothing);
      // Profile is open to everyone.
      expect(find.text('My Profile'), findsOneWidget);
      expectNoRealErrors(tester);
    });
  });
}
