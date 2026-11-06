import 'package:flutter/widgets.dart';

/// Grows a fixed height with the phone's text-size setting, so cards built on a
/// fixed height still fit their text when someone uses large fonts.
double textScaled(BuildContext context, double base) =>
    base * MediaQuery.textScalerOf(context).scale(14) / 14;
