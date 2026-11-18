import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/profile_screen.dart';

import 'test_helpers.dart';

/// A ListTile inside a coloured card needs a Material between the two, or its
/// ripple and colours are hidden (Flutter reports "ListTile background color
/// or ink splashes may be invisible"). The profile page lists its rows in a
/// white card, so build that card with a few rows and check for the report.
void main() {
  testWidgets('profile rows in their card keep the ripple', (tester) async {
    ignoreFontErrors();
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileGroup(
            children: [
              ProfileRow(
                icon: Icons.lock_reset_rounded,
                label: 'Change password',
                onTap: () => tapped++,
              ),
              ProfileRow(
                icon: Icons.logout_rounded,
                label: 'Log out',
                danger: true,
                onTap: () => tapped++,
              ),
            ],
          ),
        ),
      ),
    );
    expectNoRealErrors(tester);

    await tester.tap(find.text('Change password'));
    await tester.pump();
    expect(tapped, 1);
    expectNoRealErrors(tester);
  });
}
