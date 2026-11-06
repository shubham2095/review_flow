import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/brand.dart';

/// The server's password rule: 8 or more characters, upper and lower case
/// letters, and a number. Checked here first so nobody finds out from an error.
class PasswordRules {
  PasswordRules._();

  static bool hasLength(String p) => p.length >= 8;
  static bool hasCase(String p) =>
      RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p);
  static bool hasNumber(String p) => RegExp(r'\d').hasMatch(p);

  static bool ok(String p) => hasLength(p) && hasCase(p) && hasNumber(p);

  /// One sentence about what is missing, or null when the password is fine.
  static String? problem(String p) {
    if (ok(p)) return null;
    final missing = <String>[
      if (!hasLength(p)) 'at least 8 characters',
      if (!hasCase(p)) 'upper and lower case letters',
      if (!hasNumber(p)) 'a number',
    ];
    return 'Use ${missing.join(', ')}.';
  }
}

/// Three ticks under a password field that turn green as the rule is met.
class PasswordRulesView extends StatelessWidget {
  const PasswordRulesView({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    Widget rule(String text, bool done) {
      final color = done ? good : muted;
      return Padding(
        padding: const EdgeInsets.only(right: 12, top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: color,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: PasswordRules.problem(password) ?? 'Password meets all rules',
      child: Wrap(
        children: [
          rule('8+ characters', PasswordRules.hasLength(password)),
          rule('Aa letters', PasswordRules.hasCase(password)),
          rule('A number', PasswordRules.hasNumber(password)),
        ],
      ),
    );
  }
}
