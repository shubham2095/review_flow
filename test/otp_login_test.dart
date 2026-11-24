import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/services/api_service.dart';
import 'package:review_flow/services/otp_login.dart';

void main() {
  group('normalizeOtpPhone', () {
    test('a plain 10-digit number gets +91', () {
      expect(normalizeOtpPhone('9876543210'), '919876543210');
      expect(normalizeOtpPhone('98765 43210'), '919876543210');
      expect(normalizeOtpPhone(' 98765-43210 '), '919876543210');
    });

    test('a number that already has the code is kept as is', () {
      expect(normalizeOtpPhone('+91 98765 43210'), '919876543210');
      expect(normalizeOtpPhone('919876543210'), '919876543210');
      expect(normalizeOtpPhone('0091 98765 43210'), '919876543210');
    });

    test('a leading 0 is dropped', () {
      expect(normalizeOtpPhone('09876543210'), '919876543210');
    });

    test('a number that starts with 91 is not mistaken for the code', () {
      expect(normalizeOtpPhone('9123456789'), '919123456789');
    });

    test('too short, too long, letters and blanks are refused', () {
      expect(normalizeOtpPhone(''), isNull);
      expect(normalizeOtpPhone('   '), isNull);
      expect(normalizeOtpPhone('98765'), isNull);
      expect(normalizeOtpPhone('abc'), isNull);
      expect(normalizeOtpPhone('98765432101234'), isNull);
    });

    test('an Indian number must start 6 to 9', () {
      expect(normalizeOtpPhone('5876543210'), isNull);
      expect(normalizeOtpPhone('1234567890'), isNull);
      expect(normalizeOtpPhone('6000000000'), '916000000000');
    });

    test('another country needs an explicit + or 00', () {
      expect(normalizeOtpPhone('+44 7911 123456'), '447911123456');
      expect(normalizeOtpPhone('0044 7911 123456'), '447911123456');
      expect(normalizeOtpPhone('+1 415 555 2671'), '14155552671');
    });

    test('the default country code can be changed', () {
      expect(
        normalizeOtpPhone('7911123456', countryCode: '44'),
        '447911123456',
      );
    });
  });

  group('formatPhoneInput', () {
    test('ten digits in two groups of five', () {
      expect(formatPhoneInput(''), '');
      expect(formatPhoneInput('98765'), '98765');
      expect(formatPhoneInput('987654'), '98765 4');
      expect(formatPhoneInput('9876543210'), '98765 43210');
      expect(formatPhoneInput('98765 43210'), '98765 43210');
    });

    test('more than ten digits are cut', () {
      expect(formatPhoneInput('98765432109999'), '98765 43210');
    });

    test('a number typed that begins with 91 is kept whole', () {
      expect(formatPhoneInput('9123456789'), '91234 56789');
      // Typing an eleventh digit adds nothing (it is not read as a prefix).
      expect(formatPhoneInput('91234567890'), '91234 56789');
    });

    test('a pasted prefix is removed', () {
      expect(formatPhoneInput('+91 98765 43210', pasted: true), '98765 43210');
      expect(formatPhoneInput('919876543210', pasted: true), '98765 43210');
      expect(formatPhoneInput('00919876543210', pasted: true), '98765 43210');
      expect(formatPhoneInput('09876543210', pasted: true), '98765 43210');
      expect(formatPhoneInput('0919876543210', pasted: true), '98765 43210');
      // A pasted ten-digit number that begins with 91 is not cut.
      expect(formatPhoneInput('9123456789', pasted: true), '91234 56789');
    });

    test('what it shows is what normalizeOtpPhone expects', () {
      expect(normalizeOtpPhone(formatPhoneInput('9876543210')), '919876543210');
    });
  });

  group('display and code box', () {
    test('formatOtpPhone', () {
      expect(formatOtpPhone('919876543210'), '+91 98765 43210');
      expect(formatOtpPhone('447911123456'), '+447911123456');
    });

    test('cleanOtpCode keeps six digits only', () {
      expect(cleanOtpCode('12 34-56'), '123456');
      expect(cleanOtpCode('1234567890'), '123456');
      expect(cleanOtpCode('ab12'), '12');
    });

    test('otpCodeComplete', () {
      expect(otpCodeComplete('123456'), isTrue);
      expect(otpCodeComplete('12345'), isFalse);
      expect(otpCodeComplete('12345a'), isFalse);
      expect(otpCodeComplete(''), isFalse);
    });

    test('the server sends six digits and waits 30 seconds', () {
      expect(kOtpCodeLength, 6);
      expect(kOtpResendSeconds, 30);
    });
  });

  group('otpErrorMessage', () {
    test('a resend that is too soon shows the real wait message', () {
      final e = ApiException(
        'The given data was invalid.',
        statusCode: 422,
        errors: {
          'phone': [
            'Please wait a few seconds before requesting another code.',
          ],
        },
      );
      expect(
        otpErrorMessage(e),
        'Please wait a few seconds before requesting another code.',
      );
    });

    test('the generic invalid-data line becomes a plain one', () {
      final e = ApiException('The given data was invalid.', statusCode: 422);
      expect(otpErrorMessage(e), 'Please check the number and try again.');
    });

    test('a number with no account points to the other options', () {
      final e = ApiException(
        'This mobile number is not linked to any account. Save it on your '
        'profile (or sign in with email), then try again.',
        statusCode: 422,
      );
      final text = otpErrorMessage(e);
      expect(text, contains('No Eydia account uses this number'));
      expect(text, isNot(contains('Save it on your profile')));
    });

    test('a wrong or expired code keeps the server wording', () {
      final e = ApiException(
        'That code is invalid or has expired. Please try again.',
        statusCode: 422,
      );
      expect(otpErrorMessage(e), e.message);
    });

    test('offline and server-down messages pass through', () {
      final offline = ApiException(kNetworkMessage, code: 'offline');
      expect(otpErrorMessage(offline), kNetworkMessage);
      final down = ApiException('Server is busy.', statusCode: 503);
      expect(otpErrorMessage(down), 'Server is busy.');
    });

    test('too many requests', () {
      final e = ApiException(
        'Too many requests. Please wait a moment.',
        statusCode: 429,
      );
      expect(otpErrorMessage(e), contains('wait a minute'));
    });
  });

  group('AuthService talks to the right paths', () {
    final source = File('lib/services/auth_service.dart').readAsStringSync();

    test('request and verify use the OTP endpoints, signed out', () {
      expect(source, contains("'/auth/otp/request'"));
      expect(source, contains("'/auth/otp/verify'"));
      final request = RegExp(r"'/auth/otp/request',[\s\S]*?auth: false");
      final verify = RegExp(r"'/auth/otp/verify',[\s\S]*?auth: false");
      expect(request.hasMatch(source), isTrue);
      expect(verify.hasMatch(source), isTrue);
    });

    test('register is sent only when asked for', () {
      expect(source, contains("if (register) 'register': true"));
    });

    test('a verified code is stored like an email login', () {
      final verify = source.substring(
        source.indexOf('static Future<void> verifyOtp'),
      );
      expect(verify.substring(0, 500), contains('await _store(data)'));
    });
  });
}
