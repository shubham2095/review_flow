import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/theme/brand.dart';
import 'package:review_flow/widgets/wa_ui.dart';

import 'test_helpers.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StatusBadge shows its text and is read as a status', (
    tester,
  ) async {
    ignoreFontErrors();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const StatusBadge('Approved', good)));

    expect(find.text('Approved'), findsOneWidget);
    expect(find.bySemanticsLabel('Status: Approved'), findsOneWidget);
    expectNoRealErrors(tester);
    handle.dispose();
  });

  testWidgets('ContactAvatar: same name, same colour, right initial', (
    tester,
  ) async {
    ignoreFontErrors();
    expect(ContactAvatar.colorFor('Priya'), ContactAvatar.colorFor('priya '));
    expect(ContactAvatar.colorFor(''), muted);
    expect(ContactAvatar.initialOf('priya sharma'), 'P');
    expect(ContactAvatar.initialOf('   '), '?');

    await tester.pumpWidget(_host(const ContactAvatar(name: 'asha')));
    expect(find.text('A'), findsOneWidget);
    await tester.pumpWidget(_host(const ContactAvatar(name: '')));
    expect(find.text('?'), findsOneWidget);
    expectNoRealErrors(tester);
  });

  testWidgets('AppSheet shows its title, help line and content', (
    tester,
  ) async {
    ignoreFontErrors();
    await tester.pumpWidget(
      _host(
        const AppSheet(
          title: 'Connect a number',
          subtitle: 'Copy these from Meta',
          child: Text('Body of the sheet'),
        ),
      ),
    );

    expect(find.text('Connect a number'), findsOneWidget);
    expect(find.text('Copy these from Meta'), findsOneWidget);
    expect(find.text('Body of the sheet'), findsOneWidget);
    expectNoRealErrors(tester);
  });

  testWidgets('ContentWidth caps the width on a wide screen only', (
    tester,
  ) async {
    ignoreFontErrors();
    const key = Key('content');

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _host(
        const ContentWidth(
          child: SizedBox(key: key, width: double.infinity, height: 40),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(key)).width, 720);

    // A phone is narrower than the cap, so nothing changes.
    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();
    expect(tester.getSize(find.byKey(key)).width, 400);
    expectNoRealErrors(tester);
  });

  testWidgets('StatTile is announced as "label: value" and can be tapped', (
    tester,
  ) async {
    ignoreFontErrors();
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        StatTile(
          label: 'Unread',
          value: 5,
          icon: Icons.mark_chat_unread_rounded,
          highlight: true,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.bySemanticsLabel('Unread: 5'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    await tester.tap(find.byType(StatTile));
    expect(taps, 1);
    expectNoRealErrors(tester);
    handle.dispose();
  });
}
