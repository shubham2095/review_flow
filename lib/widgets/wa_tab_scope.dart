import 'package:flutter/widgets.dart';

/// Tells a screen that lives in a tab whether its tab is the one on screen.
///
/// Tabs stay alive when the person switches away (their scroll position and
/// data are kept), so a screen that refreshes itself on a timer would keep
/// calling the server from the background. Such a screen asks
/// [WaTabScope.isActive] and skips the refresh while hidden, then catches up
/// when it becomes visible again.
///
/// A screen that is not inside a tab (opened full-screen) finds no scope and
/// is treated as visible, so nothing changes for it.
class WaTabScope extends InheritedWidget {
  const WaTabScope({super.key, required this.active, required super.child});

  final bool active;

  /// Whether the nearest tab is visible. True when there is no tab scope.
  /// Call from `didChangeDependencies` or `build` so changes are noticed.
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WaTabScope>()?.active ?? true;

  @override
  bool updateShouldNotify(WaTabScope oldWidget) => oldWidget.active != active;
}
