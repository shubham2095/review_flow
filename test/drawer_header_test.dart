import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:review_flow/screens/pages.dart';
import 'package:review_flow/services/products.dart';
import 'package:review_flow/services/session.dart';
import 'package:review_flow/widgets/app_drawer.dart';

import 'test_helpers.dart';

void main() {
  for (final product in Product.values) {
    testWidgets('tapping the name at the top of the ${product.name} menu '
        'opens the profile', (tester) async {
      ignoreFontErrors();
      PackageInfo.setMockInitialValues(
        appName: 'Eydia',
        packageName: 'com.heltog.review_flow',
        version: '2.1.0',
        buildNumber: '1',
        buildSignature: '',
      );
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int? opened;
      final key = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: key,
            drawer: AppDrawer(
              name: 'Jay Kushwah',
              email: 'jay@example.com',
              selectedIndex: 0,
              onSelect: (i) => opened = i,
              onLogout: () {},
              product: product,
              onHub: () {},
              user: AppUser(
                id: '1',
                name: 'Jay Kushwah',
                email: 'jay@example.com',
              ),
            ),
            body: const SizedBox(),
          ),
        ),
      );
      key.currentState!.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jay Kushwah'));
      await tester.pumpAndSettle();

      expect(opened, kPageAccount);
      expect(key.currentState!.isDrawerOpen, isFalse);
      expectNoRealErrors(tester);
    });
  }
}
