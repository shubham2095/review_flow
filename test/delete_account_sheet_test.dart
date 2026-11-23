import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/delete_account_sheet.dart';
import 'package:review_flow/services/api_service.dart';
import 'package:review_flow/services/otp_login.dart';

import 'test_helpers.dart';

class _Calls {
  final requests = <String>[];
  final deletes = <({String? password, String? idToken, String? code})>[];
  Object? deleteError;
  Object? requestError;
  String? devCode;

  Future<OtpRequestResult> request(
    String phone, {
    required bool register,
  }) async {
    requests.add(phone);
    final error = requestError;
    if (error != null) throw error;
    return OtpRequestResult(message: 'sent', devCode: devCode);
  }

  Future<void> delete({String? password, String? idToken, String? code}) async {
    deletes.add((password: password, idToken: idToken, code: code));
    final error = deleteError;
    if (error != null) throw error;
  }
}

/// Opens the sheet from a button and records what it closed with.
class _Host extends StatefulWidget {
  const _Host({required this.calls, this.phone, this.codeFirst});

  final _Calls calls;
  final String? phone;
  final bool? codeFirst;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final r = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (_) => DeleteAccountSheet(
                phone: widget.phone,
                codeFirst: widget.codeFirst,
                requestCode: widget.calls.request,
                delete: widget.calls.delete,
              ),
            );
            setState(() => result = r);
          },
          child: Text('Open ${result ?? ''}'),
        ),
      ),
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  _Calls calls, {
  String? phone,
  bool? codeFirst,
  Size size = const Size(420, 1400),
  double textScale = 1,
}) async {
  ignoreFontErrors();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: _Host(calls: calls, phone: phone, codeFirst: codeFirst),
    ),
  );
  await tester.tap(find.textContaining('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _typeDelete(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Type DELETE to confirm'),
    'delete',
  );
  await tester.pump();
}

FilledButton _button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

void main() {
  group('helpers', () {
    test('code first only for a mobile account with a number', () {
      expect(deleteWithCodeFirst(hasPhone: true, standInEmail: true), isTrue);
      expect(deleteWithCodeFirst(hasPhone: true, standInEmail: false), isFalse);
      expect(deleteWithCodeFirst(hasPhone: false, standInEmail: true), isFalse);
    });

    test('server reasons become plain sentences', () {
      final wrong = ApiException(
        'The verification code is incorrect or has expired.',
        statusCode: 422,
        code: 'otp_invalid',
      );
      expect(
        otpDeleteErrorMessage(wrong),
        contains('incorrect or has expired'),
      );
      final noPhone = ApiException(
        'No phone.',
        statusCode: 422,
        code: 'no_phone',
      );
      expect(otpDeleteErrorMessage(noPhone), contains('No mobile number'));
      final other = ApiException('Server is busy.', statusCode: 503);
      expect(otpDeleteErrorMessage(other), 'Server is busy.');
    });

    test('AuthService sends the code in the delete body', () {
      final source = File('lib/services/auth_service.dart').readAsStringSync();
      expect(source, contains("'code': ?code"));
      // Notifications come back when the delete is refused.
      expect(source, contains('PushService.enable()'));
    });
  });

  group('an account made with a mobile number', () {
    testWidgets('asks for a code, not a password', (tester) async {
      final calls = _Calls();
      await _open(tester, calls, phone: '+919876543210', codeFirst: true);

      expect(find.textContaining('+91 98765 43210'), findsOneWidget);
      expect(find.text('Send code to WhatsApp'), findsOneWidget);
      expect(find.text('Your password'), findsNothing);
      expect(find.text('Use my password instead'), findsOneWidget);
      expectNoRealErrors(tester);
    });

    testWidgets('nothing is sent until DELETE is typed', (tester) async {
      final calls = _Calls();
      await _open(tester, calls, phone: '+919876543210', codeFirst: true);

      expect(_button(tester, 'Send code to WhatsApp').onPressed, isNull);
      await _typeDelete(tester);
      expect(_button(tester, 'Send code to WhatsApp').onPressed, isNotNull);
      expect(calls.requests, isEmpty);
    });

    testWidgets('the code goes to their own number and deletes the account', (
      tester,
    ) async {
      final calls = _Calls();
      await _open(tester, calls, phone: '+919876543210', codeFirst: true);
      await _typeDelete(tester);

      await tester.tap(find.text('Send code to WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.requests, ['919876543210']);
      expect(find.text('6-digit code'), findsOneWidget);
      expect(find.text('Resend in 30s'), findsOneWidget);
      // Five digits are not enough, and nothing deletes by itself.
      await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'),
        '12345',
      );
      await tester.pump();
      expect(_button(tester, 'Delete my account').onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'),
        '123456',
      );
      await tester.pump();
      expect(calls.deletes, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(calls.deletes.single.code, '123456');
      expect(calls.deletes.single.password, isNull);
      // The sheet closed with true.
      expect(find.text('Open true'), findsOneWidget);
    });

    testWidgets('a wrong code shows why and clears the box', (tester) async {
      final calls = _Calls()
        ..deleteError = ApiException(
          'The verification code is incorrect or has expired.',
          statusCode: 422,
          code: 'otp_invalid',
        );
      await _open(tester, calls, phone: '+919876543210', codeFirst: true);
      await _typeDelete(tester);
      await tester.tap(find.text('Send code to WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'),
        '000000',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('incorrect or has expired'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '6-digit code'))
            .controller!
            .text,
        '',
      );
      // Still open, and the account is still there.
      expect(find.text('Delete your account'), findsOneWidget);
    });

    testWidgets('resend waits 30 seconds', (tester) async {
      final calls = _Calls();
      await _open(tester, calls, phone: '+919876543210', codeFirst: true);
      await _typeDelete(tester);
      await tester.tap(find.text('Send code to WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      for (var i = 0; i < kOtpResendSeconds; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('Resend code'), findsOneWidget);
      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.requests, hasLength(2));
      expect(find.text('A new code is on its way.'), findsOneWidget);
    });

    testWidgets('a code that cannot be sent says why', (tester) async {
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
      await _open(tester, calls, phone: '+919876543210', codeFirst: true);
      await _typeDelete(tester);

      await tester.tap(find.text('Send code to WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Please wait a few seconds'), findsOneWidget);
      expect(find.text('6-digit code'), findsNothing);
    });

    testWidgets('they can still use a password', (tester) async {
      final calls = _Calls();
      await _open(tester, calls, phone: '+919876543210', codeFirst: true);

      await tester.tap(find.text('Use my password instead'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Your password'), findsOneWidget);
      expect(find.text('Send code to WhatsApp'), findsNothing);

      await _typeDelete(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Your password'),
        'Secret123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls.deletes.single.password, 'Secret123');
      expect(calls.deletes.single.code, isNull);
    });
  });

  group('an account with a password', () {
    testWidgets('starts with the password, and offers a code too', (
      tester,
    ) async {
      final calls = _Calls();
      await _open(tester, calls, phone: '+919876543210', codeFirst: false);

      expect(find.text('Your password'), findsOneWidget);
      expect(find.text('No password? Get a code on WhatsApp'), findsOneWidget);

      await tester.tap(find.text('No password? Get a code on WhatsApp'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Send code to WhatsApp'), findsOneWidget);
    });

    testWidgets('without a saved number there is no code option', (
      tester,
    ) async {
      final calls = _Calls();
      await _open(tester, calls, phone: '', codeFirst: true);

      // Even a "code first" account falls back to the password: no number.
      expect(find.text('Your password'), findsOneWidget);
      expect(find.textContaining('Get a code on WhatsApp'), findsNothing);
      expect(find.text('Send code to WhatsApp'), findsNothing);
    });

    testWidgets('a wrong password keeps the sheet open', (tester) async {
      final calls = _Calls()
        ..deleteError = ApiException(
          'Current password is incorrect.',
          statusCode: 422,
        );
      await _open(tester, calls, phone: '', codeFirst: false);
      await _typeDelete(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Your password'),
        'nope',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Current password is incorrect.'), findsOneWidget);
      expect(find.text('Delete your account'), findsOneWidget);
    });
  });

  testWidgets('the code step fits a small phone at 1.5x text', (tester) async {
    final calls = _Calls()
      ..deleteError = ApiException(
        'The verification code is incorrect or has expired.',
        statusCode: 422,
        code: 'otp_invalid',
      );
    await _open(
      tester,
      calls,
      phone: '+919876543210',
      codeFirst: true,
      size: const Size(360, 640),
      textScale: 1.5,
    );
    await _typeDelete(tester);
    await tester.ensureVisible(find.text('Send code to WhatsApp'));
    await tester.tap(find.text('Send code to WhatsApp'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.widgetWithText(TextField, '6-digit code'),
      '111111',
    );
    await tester.pump();
    // On a small phone with big text the sheet scrolls, as it does for a person.
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Delete my account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete my account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('incorrect or has expired'), findsOneWidget);
    expectNoRealErrors(tester);
  });
}
