import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// The navy-to-violet screen background used by the sign-in and plan screens,
/// with soft glowing circles for depth. Decoration never affects layout.
class RoyalBackdrop extends StatelessWidget {
  const RoyalBackdrop({super.key, required this.child});

  final Widget child;

  Widget _glow(Color color, double size) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [royalNavy, royalIndigo, royalViolet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(top: -90, right: -80, child: _glow(royalGold, 280)),
          Positioned(bottom: -120, left: -100, child: _glow(brandDeep, 320)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
