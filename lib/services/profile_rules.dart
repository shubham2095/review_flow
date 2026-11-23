import 'api_service.dart';

/// Someone who signs up with a mobile number gets an account made for them
/// with stand-in details; they fill in the real ones from their profile. These
/// helpers tell a stand-in from a real value, so the app never shows
/// "New User" or `otp_919876543210@users.eydia.in` as if it were the person.

final _standInEmail = RegExp(
  r'^otp_\d+@users\.eydia\.in$',
  caseSensitive: false,
);

/// The email the server makes up for a mobile-number account.
bool isStandInEmail(String? email) =>
    email != null && _standInEmail.hasMatch(email.trim());

/// The name the server gives a mobile-number account.
bool isStandInName(String? name) => name?.trim().toLowerCase() == 'new user';

/// The workspace name the server gives a mobile-number account.
bool isStandInBusiness(String? name) =>
    name?.trim().toLowerCase() == 'my workspace';

bool looksLikeEmail(String text) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text.trim());

/// "a", "a and b", "a, b and c".
String joinParts(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

/// The server's message for each field it refused, keyed by the field name
/// (`email`, `company_name`, ...). The top-level message of a refused request
/// is only "The given data was invalid.", so the real wording is in here.
Map<String, String> profileFieldErrors(ApiException e) {
  final result = <String, String>{};
  e.errors?.forEach((key, value) {
    if (value is List && value.isNotEmpty && value.first is String) {
      result[key] = value.first as String;
    } else if (value is String && value.isNotEmpty) {
      result[key] = value;
    }
  });
  return result;
}

/// One line to show for a failed profile save when no field can carry it.
String profileErrorMessage(ApiException e) {
  final fields = profileFieldErrors(e);
  if (fields.isNotEmpty) return fields.values.first;
  return e.message;
}
