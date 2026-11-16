import 'package:flutter/material.dart';

const brand = Color(0xFF4C6FFF);
const brandDeep = Color(0xFF7C5CFF);
const ink = Color(0xFF1B2437);
// Darkened from 0xFF7A8599 (3.7:1 on white) to meet the 4.5:1 text contrast minimum.
const muted = Color(0xFF5F6B80);
const surface = Color(0xFFF4F6FB);
const good = Color(0xFF22C55E);
const warn = Color(0xFFF97316);
const bad = Color(0xFFEF4444);
const star = Color(0xFFF59E0B);

// Royal palette for premium surfaces (drawer header, login).
const royalNavy = Color(0xFF0E1530);
const royalIndigo = Color(0xFF1E2A6B);
const royalViolet = Color(0xFF3B2A8C);
const royalGold = Color(0xFFD4AF37);

// Shared tokens for the WhatsApp area (and anything else that needs them).
// Softer text on cards, the grey behind progress bars, and the chat colours.
const inkSoft = Color(0xFF4A5468);
const track = Color(0xFFEEF1F7);
const waChatBg = Color(0xFFEFEAE2);
const waBubbleOut = Color(0xFFD9FDD3);
const waBubbleIn = Colors.white;
const waTick = Color(0xFF2196F3);

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
