import 'package:flutter/material.dart';

/// Label for a segmented tab: one line that never breaks mid-word ("Optimiz /
/// e"). If the phone's text size leaves no room it fades out, not wraps.
class TabLabel extends StatelessWidget {
  const TabLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}
