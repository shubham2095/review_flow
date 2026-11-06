import 'package:flutter/material.dart';

/// Wraps a tappable card with a quick scale-down on touch, so cards feel alive.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // Screen readers announce the whole card as one button; reduce-motion
    // turns the press animation off.
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down && !still ? widget.scale : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
