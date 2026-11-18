import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/screens/admin_dashboard_screen.dart';
import 'package:review_flow/theme/brand.dart';

import 'test_helpers.dart';

/// The tiles used to sit in a grid with a fixed height and overflowed on a
/// phone with larger text ("BOTTOM OVERFLOWED BY 2.0 PIXELS"). They now grow
/// with their content.
void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('dashboard tiles never overflow at ${scale}x text', (
      tester,
    ) async {
      ignoreFontErrors();
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: adminTileGrid(
                children: const [
                  AdminStatTile(
                    label: 'Total companies',
                    value: '18',
                    icon: Icons.business_rounded,
                    color: brand,
                  ),
                  AdminStatTile(
                    label: 'Active companies',
                    value: '18',
                    icon: Icons.check_circle_rounded,
                    color: good,
                    note: '2 suspended',
                  ),
                  AdminStatTile(
                    label: 'Plans',
                    value: '3',
                    icon: Icons.workspace_premium_rounded,
                    color: royalViolet,
                  ),
                  AdminStatTile(
                    label: 'Total users',
                    value: '20',
                    icon: Icons.groups_rounded,
                    color: warn,
                  ),
                  AdminStatTile(
                    label: 'Revenue',
                    value: '₹34,795.82',
                    icon: Icons.payments_rounded,
                    color: royalIndigo,
                    note: '7 paid of 7',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expectNoRealErrors(tester);
    });
  }
}
