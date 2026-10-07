import 'package:flutter/material.dart';

/// Staggered entrance: fade + slide-up + a light scale pop. Purely visual —
/// wrap any widget in it with a per-item `delay` for a cascading list effect.
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _show ? 1 : 0.96,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
