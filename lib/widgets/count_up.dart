import 'package:flutter/material.dart';

/// A number that counts up from zero when it first appears (and glides to the
/// new value when it changes).
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  final num value;
  final TextStyle style;
  final int decimals;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(
        '$prefix${decimals > 0 ? v.toStringAsFixed(decimals) : v.round().toString()}$suffix',
        maxLines: 1,
        style: style,
      ),
    );
  }
}
