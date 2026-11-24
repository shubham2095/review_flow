import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/login_screen.dart';
import 'package:review_flow/services/api_service.dart';
import 'package:review_flow/services/otp_login.dart';
import 'package:review_flow/widgets/otp_sign_in_form.dart';

import 'test_helpers.dart';

class _Calls {
  final requests = <({String phone, bool register})>[];
  final verifies = <({String phone, String code, bool register})>[];
  int signedIn = 0;

  Object? requestError;
  Object? verifyError;
  String? devCode;

  Future<OtpRequestResult> request(
    String phone, {
    required bool register,
  }) async {
    requests.add((phone: phone, register: register));
    final error = requestError;
    if (error != null) throw error;
    return OtpRequestResult(message: 'sent', devCode: devCode);
  }

  Future<void> verify(
    String phone,
    String code, {
    required bool register,
  }) async {
    verifies.add((phone: phone, code: code, register: register));
    final error = verifyError;
    if (error != null) throw error;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Calls calls, {
  bool register = false,
}) async {
  ignoreFontErrors();
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: OtpSignInForm(
            register: register,
            onSignedIn: () => calls.signedIn++,
            request: calls.request,
            verify: calls.verify,
          ),
        ),
      ),
    ),
  );
}

Future<void> _sendTo(WidgetTester tester, String number) async {
  await tester.enterText(find.byType(TextField), number);
  await tester.tap(find.text('Send code'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'a number that cannot be real is refused without asking the server',
    (tester) async {
      final calls = _Calls();
      await _pump(tester, calls);

      await _sendTo(tester, '12345');

      expect(
        find.textContaining('Enter your 10-digit mobile number'),
        findsOneWidget,
      );
      expect(calls.requests, isEmpty);
      expectNoRealErrors(tester);
    },
  );

  testWidgets('a good number asks for a code and shows the code step', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(tester, calls);

    await _sendTo(tester, '98765 43210');

    expect(calls.requests.single.phone, '919876543210');
    expect(calls.requests.single.register, isFalse);
    expect(
      find.textContaining('If +91 98765 43210 has an Eydia account'),
      findsOneWidget,
    );
    expect(find.text('Verify & sign in'), findsOneWidget);
    expect(find.text('Resend in 30s'), findsOneWidget);
    expect(find.text('Change number'), findsOneWidget);
    expectNoRealErrors(tester);
  });

  testWidgets('resend waits 30 seconds, then asks again', (tester) async {
    final calls = _Calls();
    await _pump(tester, calls);
    await _sendTo(tester, '9876543210');

    // Tapping while it counts down does nothing.
    await tester.tap(find.text('Resend in 30s'));
    await tester.pump();
    expect(calls.requests, hasLength(1));

    for (var i = 0; i < kOtpResendSeconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Resend code'), findsOneWidget);

    await tester.tap(find.text('Resend code'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls.requests, hasLength(2));
    expect(find.text('A new code is on its way.'), findsOneWidget);
    expect(find.text('Resend in 30s'), findsOneWidget);
  });

  testWidgets('the sixth digit signs in by itself', (tester) async {
    final calls = _Calls();
    await _pump(tester, calls);
    await _sendTo(tester, '9876543210');

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump();

    expect(calls.verifies.single.phone, '919876543210');
    expect(calls.verifies.single.code, '123456');
    expect(calls.verifies.single.register, isFalse);
    expect(calls.signedIn, 1);
  });

  testWidgets('five digits do nothing yet, and the button stays off', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(tester, calls);
    await _sendTo(tester, '9876543210');

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();

    expect(calls.verifies, isEmpty);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('a wrong code shows the message and clears the box', (
    tester,
  ) async {
    final calls = _Calls()
      ..verifyError = ApiException(
        'That code is invalid or has expired. Please try again.',
        statusCode: 422,
      );
    await _pump(tester, calls);
    await _sendTo(tester, '9876543210');

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('That code is invalid or has expired. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(calls.signedIn, 0);
  });

  testWidgets('a lost connection keeps the code that was typed', (
    tester,
  ) async {
    final calls = _Calls()
      ..verifyError = ApiException(kNetworkMessage, code: 'offline');
    await _pump(tester, calls);
    await _sendTo(tester, '9876543210');

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(kNetworkMessage), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '123456',
    );
  });

  testWidgets('a code request that fails says why', (tester) async {
    final calls = _Calls()
      ..requestError = ApiException(
        'The given data was invalid.',
        statusCode: 422,
        errors: {
          'phone': [
            'Please wait a few seconds before requesting another code.',
          ],
        },
      );
    await _pump(tester, calls);

    await _sendTo(tester, '9876543210');

    expect(
      find.text('Please wait a few seconds before requesting another code.'),
      findsOneWidget,
    );
    // Still on the number step, so it can be tried again.
    expect(find.text('Send code'), findsOneWidget);
  });

  testWidgets('Change number goes back and keeps the number typed', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(tester, calls);
    await _sendTo(tester, '9876543210');

    await tester.tap(find.text('Change number'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Verify & sign in'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '98765 43210',
    );
  });

  testWidgets('the number is grouped as it is typed, a pasted +91 is cleaned', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(tester, calls);
    TextEditingController field() =>
        tester.widget<TextField>(find.byType(TextField)).controller!;

    await tester.enterText(find.byType(TextField), '9876543210');
    expect(field().text, '98765 43210');

    await tester.enterText(find.byType(TextField), '+91 98765-43210');
    expect(field().text, '98765 43210');

    await tester.enterText(find.byType(TextField), '0919876543210');
    expect(field().text, '98765 43210');

    // The +91 is drawn in front of the field.
    expect(find.text('+91'), findsOneWidget);
    // Typing into a full field adds nothing.
    await tester.enterText(find.byType(TextField), '98765432109');
    expect(field().text, '98765 43210');
  });

  testWidgets('the code shows in six boxes, one digit each', (tester) async {
    final calls = _Calls();
    await _pump(tester, calls);
    await _sendTo(tester, '9876543210');

    await tester.enterText(find.byType(TextField), '482');
    await tester.pump();

    expect(find.text('4'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    // Still one real text field underneath, so autofill and paste work.
    expect(find.byType(TextField), findsOneWidget);
    expectNoRealErrors(tester);
  });

  testWidgets('a development server code is shown as a test code', (
    tester,
  ) async {
    final calls = _Calls()..devCode = '482913';
    await _pump(tester, calls);

    await _sendTo(tester, '9876543210');

    expect(find.text('Test code: 482913'), findsOneWidget);
  });

  testWidgets('a new number is sent with register and says so', (tester) async {
    final calls = _Calls();
    await _pump(tester, calls, register: true);

    await _sendTo(tester, '9876543210');
    expect(calls.requests.single.register, isTrue);
    expect(
      find.textContaining('Code sent on WhatsApp to +91 98765 43210'),
      findsOneWidget,
    );
    expect(find.text('Verify & create account'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump();
    expect(calls.verifies.single.register, isTrue);
    expect(calls.signedIn, 1);
  });

  testWidgets('the code step fits a small phone at 1.5x text', (tester) async {
    final calls = _Calls()
      ..verifyError = ApiException(
        'That code is invalid or has expired. Please try again.',
        statusCode: 422,
      );
    ignoreFontErrors();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: OtpSignInForm(
              onSignedIn: () {},
              request: calls.request,
              verify: calls.verify,
            ),
          ),
        ),
      ),
    );

    await _sendTo(tester, '9876543210');
    expect(find.text('Verify & sign in'), findsOneWidget);
    // An error line on top of everything else must still fit.
    await tester.enterText(find.byType(TextField), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('invalid or has expired'), findsOneWidget);
    expectNoRealErrors(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expectNoRealErrors(tester);
  });

  group('on the login screen', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      ignoreFontErrors();
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(onLoggedIn: () {})),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('the mobile number is the first way to sign in', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in with a code sent on WhatsApp'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      expect(find.text('Use email and password instead'), findsOneWidget);
      // Google sits under the form, after an "or".
      expect(find.text('or'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expectNoRealErrors(tester);
    });

    testWidgets('the terms and privacy links are under the card', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining('By continuing you agree'), findsOneWidget);
    });

    testWidgets('email and password is one tap away, and back again', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Use email and password instead'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Sign in with your email and password'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Send code'), findsNothing);
      expect(find.text('Use mobile number instead'), findsOneWidget);
      expectNoRealErrors(tester);

      await tester.tap(find.text('Use mobile number instead'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Send code'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
    });

    testWidgets('Create account starts with the mobile number too', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Create account'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create your account'), findsOneWidget);
      expect(
        find.text('Just your mobile number to get started'),
        findsOneWidget,
      );
      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      expect(
        find.textContaining('add your business name and email later'),
        findsOneWidget,
      );
      expect(find.text('Business name'), findsNothing);
      expectNoRealErrors(tester);
    });

    testWidgets('Create account with Email is the form it always was', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Create account'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Use email and password instead'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Business name'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Send code'), findsNothing);
      expectNoRealErrors(tester);
    });

    testWidgets('going back to Sign in brings back the sign-in wording', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(find.text('Create account'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Sign in'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.textContaining('add your business name and email later'),
        findsNothing,
      );
      expectNoRealErrors(tester);
    });

    testWidgets('iOS says a plan is needed, under the mobile sign-up', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpLogin(tester);
        await tester.tap(find.text('Create account'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.textContaining('Eydia is a service for businesses'),
          findsOneWidget,
        );
        expect(find.text('Send code'), findsOneWidget);
        expectNoRealErrors(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
