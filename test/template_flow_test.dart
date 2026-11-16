import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/whatsapp_template_create_screen.dart';
import 'package:review_flow/widgets/wa_template_preview.dart';

import 'test_helpers.dart';

void main() {
  group('splitFields', () {
    test('plain text is one piece', () {
      final parts = splitFields('Thanks for visiting', const {});
      expect(parts.length, 1);
      expect(parts.single.field, isNull);
    });

    test('a field shows its example, or {{n}} until one is typed', () {
      final withExample = splitFields('Hi {{1}}, order {{2}}', {1: 'Priya'});
      expect(withExample.map((p) => p.text).join(), 'Hi Priya, order {{2}}');
      expect(withExample.where((p) => p.field != null).length, 2);

      final none = splitFields('Hi {{1}}', const {});
      expect(none.map((p) => p.text).join(), 'Hi {{1}}');
    });

    test('spaces inside the braces are fine, blank examples count as none', () {
      final parts = splitFields('Hi {{ 1 }}!', {1: '   '});
      expect(parts.map((p) => p.text).join(), 'Hi {{1}}!');
    });
  });

  testWidgets('the create flow walks Basics, Content, Buttons, Review', (
    tester,
  ) async {
    ignoreFontErrors();
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: WhatsAppTemplateCreateScreen()),
    );

    // Step 1, Basics: a name is needed before Next.
    expect(find.text('Template name'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.textContaining('Give the template a name'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'order_update');
    await tester.tap(find.text('Next'));
    await tester.pump();

    // Step 2, Content: a field needs an example before Next.
    expect(find.text('Message text'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Hi {{1}}, thanks');
    await tester.pump();
    expect(find.text('Example for {{1}}'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.textContaining('Add an example for {{1}}'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Priya');
    await tester.pump();
    // The live preview shows the example in place of the field.
    expect(
      find.textContaining('Hi Priya, thanks', findRichText: true),
      findsWidgets,
    );
    await tester.tap(find.text('Next'));
    await tester.pump();

    // Step 3, Buttons (optional), then Step 4, Review.
    expect(find.text('Add a button'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Submit for approval'), findsOneWidget);
    expect(find.text('order_update'), findsOneWidget);

    // Back goes one step at a time.
    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('Add a button'), findsOneWidget);

    expectNoRealErrors(tester);
  });
}
