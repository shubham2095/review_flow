import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// Gives [builder] a pulsing opacity (0.3 to 0.75) shared by every placeholder
/// it draws, so a whole skeleton breathes in sync with one controller.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.builder});

  final Widget Function(BuildContext context, double opacity) builder;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  ).drive(Tween(begin: 0.3, end: 0.75));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => widget.builder(context, _opacity.value),
    );
  }
}

/// One grey placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.opacity,
    this.height = 16,
    this.width,
    this.radius = 14,
  });

  final double opacity;
  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: muted.withValues(alpha: opacity * 0.25),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A scrolling list of card-shaped placeholders: an optional header block
/// followed by [count] rows. Never scrolls, so it cannot overflow.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 4,
    this.itemHeight = 96,
    this.headerHeight,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  final int count;
  final double itemHeight;
  final double? headerHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      builder: (context, opacity) => ListView(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (headerHeight != null) ...[
            SkeletonBox(opacity: opacity, height: headerHeight!, radius: 22),
            const SizedBox(height: 14),
          ],
          for (var i = 0; i < count; i++) ...[
            Container(
              height: itemHeight,
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  SkeletonBox(opacity: opacity, width: 44, height: 44, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(opacity: opacity, height: 12, width: 140, radius: 6),
                        const SizedBox(height: 10),
                        SkeletonBox(opacity: opacity, height: 10, radius: 6),
                        const SizedBox(height: 6),
                        SkeletonBox(opacity: opacity, height: 10, width: 200, radius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Placeholder grid for photo tiles.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key, this.count = 6, this.extent = 200});

  final int count;
  final double extent;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      builder: (context, opacity) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: extent,
        ),
        itemBuilder: (_, _) => SkeletonBox(opacity: opacity, radius: 22, height: extent),
      ),
    );
  }
}
