import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/profile_screen.dart';
import 'package:review_flow/services/api_service.dart';
import 'package:review_flow/services/profile_rules.dart';
import 'package:review_flow/services/session.dart';

import 'test_helpers.dart';

AppUser _otpUser({
  String name = 'New User',
  String email = 'otp_919876543210@users.eydia.in',
  String? business = 'My Workspace',
  List<String> roles = const ['owner'],
}) => AppUser.fromJson({
  'id': '1',
  'name': name,
  'email': email,
  'phone': '+919876543210',
  'roles': roles,
  'tenant': business == null ? null : {'company_name': business},
  'subscription': {'status': 'active', 'plan_name': 'Plan'},
});

void main() {
  group('stand-in details', () {
    test('the made-up email is recognised, a real one is not', () {
      expect(isStandInEmail('otp_919876543210@users.eydia.in'), isTrue);
      expect(isStandInEmail(' OTP_9198@Users.Eydia.in '), isTrue);
      expect(isStandInEmail('asha@example.com'), isFalse);
      expect(isStandInEmail('otp_abc@users.eydia.in'), isFalse);
      expect(isStandInEmail('otp_919876543210@example.com'), isFalse);
      expect(isStandInEmail(null), isFalse);
    });

    test('the made-up name and workspace', () {
      expect(isStandInName('New User'), isTrue);
      expect(isStandInName(' new user '), isTrue);
      expect(isStandInName('Asha Rao'), isFalse);
      expect(isStandInName(''), isFalse);
      expect(isStandInBusiness('My Workspace'), isTrue);
      expect(isStandInBusiness('Acme Dental'), isFalse);
      expect(isStandInBusiness(null), isFalse);
    });

    test('joinParts reads like a sentence', () {
      expect(joinParts([]), '');
      expect(joinParts(['a']), 'a');
      expect(joinParts(['a', 'b']), 'a and b');
      expect(joinParts(['a', 'b', 'c']), 'a, b and c');
    });

    test('looksLikeEmail', () {
      expect(looksLikeEmail('a@b.co'), isTrue);
      expect(looksLikeEmail(' a@b.co '), isTrue);
      expect(looksLikeEmail('a@b'), isFalse);
      expect(looksLikeEmail('a b@c.com'), isFalse);
      expect(looksLikeEmail(''), isFalse);
    });
  });

  group('AppUser for a mobile-number account', () {
    test('a fresh account misses name, business and email', () {
      final u = _otpUser();
      expect(u.displayName, '');
      expect(u.missingProfileParts, [
        'your name',
        'your business name',
        'your email',
      ]);
    });

    test('filled-in details are not missing and the name shows', () {
      final u = _otpUser(
        name: 'Asha Rao',
        email: 'asha@example.com',
        business: 'Acme Dental',
      );
      expect(u.displayName, 'Asha Rao');
      expect(u.missingProfileParts, isEmpty);
    });

    test('an account with no business data does not ask for one', () {
      final u = _otpUser(business: null);
      expect(u.missingProfileParts, ['your name', 'your email']);
    });
  });

  group('server answers on a profile save', () {
    test('the field message is used, not the generic line', () {
      final e = ApiException(
        'The given data was invalid.',
        statusCode: 422,
        errors: {
          'email': ['The email has already been taken.'],
          'company_name': ['The company name field is required.'],
        },
      );
      expect(profileFieldErrors(e), {
        'email': 'The email has already been taken.',
        'company_name': 'The company name field is required.',
      });
      expect(profileErrorMessage(e), 'The email has already been taken.');
    });

    test('with no field messages the plain message stays', () {
      final e = ApiException('Something went wrong.', statusCode: 500);
      expect(profileFieldErrors(e), isEmpty);
      expect(profileErrorMessage(e), 'Something went wrong.');
    });
  });

  group('the profile page', () {
    Future<void> pump(WidgetTester tester, AppUser user) async {
      ignoreFontErrors();
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Session.user.value = user;
      addTearDown(Session.clear);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(onSignedOut: () {}, loadUser: () async => user),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a new mobile account shows what to fill in', (tester) async {
      await pump(tester, _otpUser());

      expect(
        find.textContaining('Add your name, your business name and your email'),
        findsOneWidget,
      );
      expect(find.text('Add your name'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Mobile verified'), findsOneWidget);
      expect(find.text('Business name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Set a password'), findsOneWidget);
      // The made-up values never reach the screen.
      expect(find.text('New User'), findsNothing);
      expect(find.textContaining('otp_'), findsNothing);
      expect(find.text('My Workspace'), findsNothing);
      expectNoRealErrors(tester);
    });

    testWidgets('a complete account looks as before', (tester) async {
      await pump(
        tester,
        _otpUser(
          name: 'Asha Rao',
          email: 'asha@example.com',
          business: 'Acme Dental',
        ),
      );

      expect(find.textContaining('to finish setting up'), findsNothing);
      expect(find.text('Asha Rao'), findsWidgets);
      expect(find.text('asha@example.com'), findsOneWidget);
      expect(find.text('Email address'), findsNothing);
      // The owner can rename the business.
      expect(find.text('Business name'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Set a password'), findsNothing);
      expectNoRealErrors(tester);
    });

    testWidgets('a team member cannot rename the business', (tester) async {
      await pump(
        tester,
        _otpUser(
          name: 'Ravi',
          email: 'ravi@example.com',
          business: 'Acme Dental',
          roles: const ['agent'],
        ),
      );

      expect(find.text('Business name'), findsNothing);
      expectNoRealErrors(tester);
    });

    testWidgets('a bad email is stopped before anything is sent', (
      tester,
    ) async {
      await pump(tester, _otpUser());

      await tester.enterText(
        find.widgetWithText(TextField, 'Email address'),
        'not-an-email',
      );
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pump();

      expect(
        find.text('Enter a valid email, like name@example.com.'),
        findsOneWidget,
      );
      expectNoRealErrors(tester);
    });

    testWidgets('leaving the stand-ins blank is not an error', (tester) async {
      await pump(tester, _otpUser());

      // Nothing changed: Save stays off, and no complaint about empty fields.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('cannot be empty'), findsNothing);
    });
  });
}
