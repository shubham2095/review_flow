import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:review_flow/models/team_models.dart';
import 'package:review_flow/screens/team_member_sheet.dart';
import 'package:review_flow/screens/team_screen.dart';
import 'package:review_flow/services/products.dart';
import 'package:review_flow/services/session.dart';
import 'package:review_flow/widgets/app_drawer.dart';

import 'test_helpers.dart';

const _catalog = [
  TeamFeature(key: 'inbox', label: 'Inbox (chats)'),
  TeamFeature(key: 'contacts', label: 'Contacts'),
  TeamFeature(key: 'campaigns', label: 'Campaigns'),
  TeamFeature(key: 'chatbot', label: 'Chatbot'),
];

TeamMember _agent(List<String> features) => TeamMember(
  id: 'u1',
  name: 'Asha',
  email: 'asha@example.com',
  features: features,
);

void main() {
  group('models', () {
    test('TeamData reads members and the feature catalog', () {
      final d = TeamData.fromJson({
        'members': [
          {
            'id': 'u1',
            'name': 'Asha',
            'email': 'asha@example.com',
            'status': 'suspended',
            'role': 'agent',
            'role_label': 'Agent',
            'features': ['inbox', 'contacts'],
            'last_login_at': '2026-11-10T08:00:00Z',
          },
          {
            'id': 'u2',
            'name': 'Owner',
            'email': 'o@example.com',
            'role': 'admin',
          },
        ],
        'features': [
          {'key': 'inbox', 'label': 'Inbox (chats)'},
        ],
      });
      expect(d.members, hasLength(2));
      expect(d.members.first.isActive, isFalse);
      expect(d.members.first.features, ['inbox', 'contacts']);
      expect(d.members.first.lastLoginAt, isNotNull);
      expect(d.members.last.isAdmin, isTrue);
      expect(d.members.last.roleLabel, 'Admin');
      expect(d.members.last.isActive, isTrue);
      expect(d.features.single.label, 'Inbox (chats)');
    });
  });

  group('teamMemberProblem', () {
    test('a new person needs name, email and an 8 character password', () {
      expect(
        teamMemberProblem(
          isNew: true,
          name: ' ',
          email: 'a@b.co',
          password: 'password1',
        ),
        isNotNull,
      );
      expect(
        teamMemberProblem(
          isNew: true,
          name: 'A',
          email: 'nope',
          password: 'password1',
        ),
        contains('email'),
      );
      expect(
        teamMemberProblem(
          isNew: true,
          name: 'A',
          email: 'a@b.co',
          password: '',
        ),
        contains('password'),
      );
      expect(
        teamMemberProblem(
          isNew: true,
          name: 'A',
          email: 'a@b.co',
          password: 'short',
        ),
        contains('8 characters'),
      );
      expect(
        teamMemberProblem(
          isNew: true,
          name: 'A',
          email: 'a@b.co',
          password: 'password1',
        ),
        isNull,
      );
    });

    test('when editing, the password may stay empty but not be too short', () {
      expect(
        teamMemberProblem(isNew: false, name: 'A', email: '', password: ''),
        isNull,
      );
      expect(
        teamMemberProblem(isNew: false, name: 'A', email: '', password: 'abc'),
        contains('8 characters'),
      );
      expect(
        teamMemberProblem(isNew: false, name: '', email: '', password: ''),
        isNotNull,
      );
    });
  });

  group('teamFeatureSummary', () {
    test('an admin has full access', () {
      const admin = TeamMember(id: '1', name: 'O', email: '', role: 'admin');
      final s = teamFeatureSummary(admin, _catalog);
      expect(s.$1, ['Full access']);
      expect(s.$2, 0);
    });

    test('shows up to three labels in catalog order and counts the rest', () {
      final two = teamFeatureSummary(_agent(['contacts', 'inbox']), _catalog);
      expect(two.$1, ['Inbox (chats)', 'Contacts']);
      expect(two.$2, 0);
      final four = teamFeatureSummary(
        _agent(['inbox', 'contacts', 'campaigns', 'chatbot']),
        _catalog,
      );
      expect(four.$1, ['Inbox (chats)', 'Contacts', 'Campaigns']);
      expect(four.$2, 1);
    });

    test('an agent with nothing ticked says so', () {
      final none = teamFeatureSummary(_agent([]), _catalog);
      expect(none.$1, ['Nothing ticked yet']);
      expect(none.$2, 0);
    });
  });

  group('Team in the drawer', () {
    Future<void> openDrawer(WidgetTester tester, AppUser user) async {
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
              name: user.name,
              email: user.email,
              selectedIndex: 0,
              onSelect: (_) {},
              onLogout: () {},
              product: Product.gbp,
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

    testWidgets('shown with team.view', (tester) async {
      await openDrawer(
        tester,
        AppUser(
          id: '1',
          name: 'Owner',
          email: 'o@example.com',
          permissions: ['team.view', 'billing.view'],
        ),
      );
      expect(find.text('Team'), findsOneWidget);
      expectNoRealErrors(tester);
    });

    testWidgets('hidden without it', (tester) async {
      await openDrawer(
        tester,
        AppUser(
          id: '2',
          name: 'Agent',
          email: 'a@example.com',
          permissions: ['conversations.view'],
        ),
      );
      expect(find.text('Team'), findsNothing);
      expectNoRealErrors(tester);
    });
  });
}
