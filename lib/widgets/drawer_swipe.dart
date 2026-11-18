import 'package:flutter/widgets.dart';

/// How far in from the left edge a swipe to the right opens the side menu.
///
/// Wider than Flutter's default (20), so the menu is easy to open with a
/// thumb, but not the whole screen: a full-width strip would steal every
/// sideways swipe from chip rows, tabs and swipe-to-act rows. It grows a
/// little on wider phones and stops at 90.
double drawerSwipeWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * 0.2).clamp(24.0, 90.0).toDouble();
