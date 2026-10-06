import 'package:flutter/material.dart';

const brand = Color(0xFF4C6FFF);
const brandDeep = Color(0xFF7C5CFF);
const ink = Color(0xFF1B2437);
const muted = Color(0xFF7A8599);
const surface = Color(0xFFF4F6FB);
const good = Color(0xFF22C55E);
const warn = Color(0xFFF97316);
const bad = Color(0xFFEF4444);
const star = Color(0xFFF59E0B);

BoxDecoration cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFEEF1F7)),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF141E3C).withValues(alpha: 0.04),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
