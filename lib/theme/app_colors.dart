import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Orange (Previously Purple)
  static const Color orange = Color(0xFFFF5200);
  static const Color orangeDark = Color(0xFFE64A19);

  // ── Hot Pink
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkDark = Color(0xFFDB2777);

  // ── Gradient (orange → pink) — use on main CTAs, hero cards, badges
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF5200), Color(0xFFEC4899)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [Color(0xFFFF5200), Color(0xFFEC4899)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFFE64A19), Color(0xFFFF5200), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
