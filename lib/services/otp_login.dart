import 'api_service.dart';

/// Mobile-OTP sign-in rules the screens share: the number format the server
/// needs, how long a code is, and plain wording for every way it can fail.
/// The server (`POST /auth/otp/request` and `/auth/otp/verify`) matches a
/// person by the last 10 digits, but delivers the code on WhatsApp to the FULL
/// number, so the country code must always go with it.

/// Length of the code the server sends.
const kOtpCodeLength = 6;

/// The server will not send another code to the same number for this long.
const kOtpResendSeconds = 30;

/// Country code added to a number typed without one.
const kDefaultCountryCode = '91';

/// The full number (country code first, digits only) for what a person typed,
/// or null when it cannot be a real mobile number.
///
/// "98765 43210", "09876543210", "+91 98765-43210" and "919876543210" all give
/// "919876543210". A number with another country code must start with "+" or
/// "00" (a bare 11 to 15 digit number is only accepted when it starts with the
/// default country code).
String? normalizeOtpPhone(
  String input, {
  String countryCode = kDefaultCountryCode,
}) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final explicit = text.startsWith('+') || text.startsWith('00');
  var digits = text.replaceAll(RegExp(r'\D'), '');
  if (text.startsWith('00')) digits = digits.substring(2);
  if (digits.isEmpty) return null;

  String full;
  if (explicit) {
    full = digits;
  } else if (digits.length > 10 && digits.startsWith(countryCode)) {
    // Already has the code. (A 10-digit number may itself begin "91".)
    full = digits;
  } else {
    // A leading 0 is the trunk prefix ("098765 43210"): not part of the number.
    final national = digits.startsWith('0') ? digits.substring(1) : digits;
    full = '$countryCode$national';
  }
  return _validFull(full) ? full : null;
}

bool _validFull(String full) {
  if (full.length < 8 || full.length > 15) return false;
  if (full.startsWith('91')) {
    // India: 10 digits after the code, starting 6 to 9.
    final national = full.substring(2);
    return RegExp(r'^[6-9]\d{9}$').hasMatch(national);
  }
  return true;
}

/// "+91 98765 43210" for display. Other countries: "+" and the digits.
String formatOtpPhone(String full) {
  final digits = full.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('91') && digits.length == 12) {
    final n = digits.substring(2);
    return '+91 ${n.substring(0, 5)} ${n.substring(5)}';
  }
  return '+$digits';
}

/// Keeps only digits and cuts to the code length, for the code box.
String cleanOtpCode(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  return digits.length > kOtpCodeLength
      ? digits.substring(0, kOtpCodeLength)
      : digits;
}

bool otpCodeComplete(String code) =>
    RegExp('^\\d{$kOtpCodeLength}\$').hasMatch(code);

/// What to say for a failed OTP call. The server's own wording is kept when it
/// is plain; the generic "The given data was invalid." is swapped for the
/// field's real message (for example the resend wait).
String otpErrorMessage(ApiException e) {
  if (e.isUnreachable || e.isOffline) return e.message;

  final fields = e.errors;
  if (fields != null) {
    for (final key in const ['phone', 'code']) {
      final v = fields[key];
      if (v is List && v.isNotEmpty && v.first is String) {
        return v.first as String;
      }
    }
  }

  final lower = e.message.toLowerCase();
  if (lower.contains('not linked')) {
    return 'No Eydia account uses this number. Create an account with your '
        'mobile number, or sign in with your email.';
  }
  if (lower.contains('given data was invalid')) {
    return 'Please check the number and try again.';
  }
  if (e.statusCode == 429) {
    return 'Too many tries. Please wait a minute and try again.';
  }
  return e.message;
}

/// Deleting an account is confirmed with a code on WhatsApp first when the
/// person most likely has no password: the account was made with a mobile
/// number (its email is still the made-up one) and a number is saved.
bool deleteWithCodeFirst({
  required bool hasPhone,
  required bool standInEmail,
}) => hasPhone && standInEmail;

/// What to say when a delete-with-code call fails. The server answers
/// `otp_invalid` for a wrong or expired code and `no_phone` when the account
/// has no mobile number to send a code to.
String otpDeleteErrorMessage(ApiException e) {
  switch (e.code) {
    case 'otp_invalid':
      return 'That code is incorrect or has expired. Ask for a new one and '
          'try again.';
    case 'no_phone':
      return 'No mobile number is saved on your account. Add it in your '
          'profile, or confirm with your password.';
  }
  return otpErrorMessage(e);
}

/// The shape of `AuthService.requestOtp`: screens take one of these so a test
/// can stand in for the server.
typedef OtpRequest =
    Future<OtpRequestResult> Function(String phone, {required bool register});

/// The server's answer to "send me a code".
class OtpRequestResult {
  const OtpRequestResult({required this.message, this.devCode});

  final String message;

  /// Only a development server echoes the code back; production sends null.
  final String? devCode;
}
