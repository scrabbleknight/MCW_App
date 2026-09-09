import 'package:flutter/material.dart';

/// Palette for Military Calisthenics for Women.
///
/// Wedge: clean feminine-athletic, not camo. Think Alo / Bala / NTC.
/// Base is warm-cool neutral charcoal with a coral-blush accent that reads
/// strong without being pastel.
class AppColors {
  AppColors._();

  // Neutrals — form the ground in both themes.
  static const Color ink = Color(0xFF0E0E10);
  static const Color night = Color(0xFF141418);
  static const Color nightSurface = Color(0xFF1D1D22);
  static const Color nightSurfaceHigh = Color(0xFF272730);
  static const Color chalk = Color(0xFFFAF7F5);
  static const Color mist = Color(0xFFF1ECE8);
  static const Color linen = Color(0xFFE7E1DC);

  // Primary accent — recruits from strength / running gear language.
  static const Color coral = Color(0xFFF16A5A);
  static const Color coralDeep = Color(0xFFD84E3E);
  static const Color coralSoft = Color(0xFFF9D3CD);

  // Support hues.
  static const Color olive = Color(0xFF5A6A4A); // subtle nod to source niche
  static const Color success = Color(0xFF5E9A6E);
  static const Color warning = Color(0xFFE0A458);
  static const Color danger = Color(0xFFC1554A);
}

extension AdaptiveColor on BuildContext {
  Color adaptiveColor(Color light, Color dark) =>
      Theme.of(this).brightness == Brightness.dark ? dark : light;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
