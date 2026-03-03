import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Purple
  static const Color purple = Color(0xFF9333EA);
  static const Color purpleDark = Color(0xFF7928CA);

  // ── Hot Pink
  static const Color pink = Color(0xFFEC4899);
  static const Color pinkDark = Color(0xFFDB2777);

  // ── Gradient (purple → pink) — use on main CTAs, hero cards, badges
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF7928CA), Color(0xFF9333EA), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
