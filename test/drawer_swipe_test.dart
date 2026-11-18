import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:review_flow/widgets/drawer_swipe.dart';

Widget _app(double width, Widget Function(BuildContext) body) {
  return MediaQuery(
    data: MediaQueryData(size: Size(width, 800)),
    child: MaterialApp(home: Builder(builder: body)),
  );
}

void main() {
  group('drawerSwipeWidth', () {
    Future<double> widthFor(WidgetTester tester, double screen) async {
      late double result;
      await tester.pumpWidget(
        _app(screen, (context) {
          result = drawerSwipeWidth(context);
          return const SizedBox();
        }),
      );
      return result;
    }

    testWidgets('a fifth of the screen on a normal phone', (tester) async {
      expect(await widthFor(tester, 360), 72);
      expect(await widthFor(tester, 400), 80);
    });

    testWidgets('never below 24 or above 90', (tester) async {
      expect(await widthFor(tester, 100), 24);
      expect(await widthFor(tester, 900), 90);
    });
  });

  group('swiping right from the left side opens the side menu', () {
    Future<GlobalKey<ScaffoldState>> pumpScaffold(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              key: key,
              drawerEdgeDragWidth: drawerSwipeWidth(context),
              drawer: const Drawer(child: Text('Menu')),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
      return key;
    }

    testWidgets('a drag that starts inside the strip opens it', (tester) async {
      final key = await pumpScaffold(tester);
      expect(key.currentState!.isDrawerOpen, isFalse);
      // 60 px in: past Flutter's default 20 px edge, inside our 72 px strip.
      await tester.dragFrom(const Offset(60, 400), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(key.currentState!.isDrawerOpen, isTrue);
    });

    testWidgets('a drag that starts farther in does not', (tester) async {
      final key = await pumpScaffold(tester);
      await tester.dragFrom(const Offset(200, 400), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(key.currentState!.isDrawerOpen, isFalse);
    });

    testWidgets('the three lines open it too', (tester) async {
      final key = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: key,
            appBar: AppBar(
              leading: Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ),
            drawer: const Drawer(child: Text('Menu')),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(key.currentState!.isDrawerOpen, isTrue);
    });
  });
}
