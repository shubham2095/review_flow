import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// Five stars showing a rating. Read aloud as one sentence ("4 out of 5
/// stars") instead of five unlabeled icons.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = star,
  });

  /// Whole stars filled, 0 to 5.
  final int rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating out of 5 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: color,
            ),
        ],
      ),
    );
  }
}
