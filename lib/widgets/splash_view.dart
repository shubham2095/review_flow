import 'package:flutter/material.dart';

import '../theme/brand.dart';
import 'royal_backdrop.dart';

/// Startup / waiting screen: the Eydia logo on the royal background with a soft
/// breathing glow, instead of a bare spinner on white.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RoyalBackdrop(
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_c.value);
              return Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: royalGold.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: royalGold.withValues(alpha: 0.15 + 0.2 * t),
                      blurRadius: 20 + 20 * t,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/eydia_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
