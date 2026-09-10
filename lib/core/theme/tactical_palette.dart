import 'package:flutter/material.dart';

/// Blue arctic-camo tactical palette for Military Calisthenics for Women.
///
/// The app ships in two brightnesses. [TacticalPalette] holds the original
/// dark-mode constants so `const` contexts (e.g. `const BoxDecoration`) still
/// compile, but new code should read colours through `context.palette` —
/// which resolves to an [AppPalette] tuned for the current [Brightness].
class TacticalPalette {
  TacticalPalette._();

  // Grounds
  static const Color abyss = Color(0xFF05070C);
  static const Color midnight = Color(0xFF0B111C);
  static const Color surface = Color(0xFF141C2B);
  static const Color surfaceHigh = Color(0xFF1E2839);
  static const Color hairline = Color(0xFF2A3346);

  // Text
  static const Color chalk = Color(0xFFF5F7FA);
  static const Color mist = Color(0xFFB8C4D6);
  static const Color muted = Color(0xFF8493AB);

  // Accents
  static const Color arctic = Color(0xFF3B82F6);
  static const Color arcticDeep = Color(0xFF1D5FD1);
  static const Color arcticSoft = Color(0xFF6FA8DC);
  static const Color glacier = Color(0xFFB6D3F1);

  // Support
  static const Color success = Color(0xFF5EC08A);
  static const Color warning = Color(0xFFE0A458);
  static const Color danger = Color(0xFFE05656);
}

/// A resolved palette for one [Brightness]. Fields mirror [TacticalPalette]
/// so a mechanical `TacticalPalette.X` → `context.palette.X` swap works.
@immutable
class AppPalette {
  const AppPalette({
    required this.abyss,
    required this.midnight,
    required this.surface,
    required this.surfaceHigh,
    required this.hairline,
    required this.chalk,
    required this.mist,
    required this.muted,
    required this.arctic,
    required this.arcticDeep,
    required this.arcticSoft,
    required this.glacier,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color abyss;
  final Color midnight;
  final Color surface;
  final Color surfaceHigh;
  final Color hairline;

  final Color chalk; // primary text / high-contrast foreground
  final Color mist; // secondary text
  final Color muted; // tertiary / disabled

  final Color arctic;
  final Color arcticDeep;
  final Color arcticSoft;
  final Color glacier;

  final Color success;
  final Color warning;
  final Color danger;

  static const AppPalette dark = AppPalette(
    abyss: Color(0xFF05070C),
    midnight: Color(0xFF0B111C),
    surface: Color(0xFF141C2B),
    surfaceHigh: Color(0xFF1E2839),
    hairline: Color(0xFF2A3346),
    chalk: Color(0xFFF5F7FA),
    mist: Color(0xFFB8C4D6),
    muted: Color(0xFF8493AB),
    arctic: Color(0xFF3B82F6),
    arcticDeep: Color(0xFF1D5FD1),
    arcticSoft: Color(0xFF6FA8DC),
    glacier: Color(0xFFB6D3F1),
    success: Color(0xFF5EC08A),
    warning: Color(0xFFE0A458),
    danger: Color(0xFFE05656),
  );

  /// Light-mode palette. Semantic roles are preserved:
  /// `abyss` / `midnight` remain the ground (near-white with a cool tint),
  /// `chalk` / `mist` / `muted` remain foreground text (dark on light),
  /// and the arctic-blue accent stays saturated for brand continuity.
  static const AppPalette light = AppPalette(
    abyss: Color(0xFFF6F8FC),
    midnight: Color(0xFFEEF2F8),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1F5FB),
    hairline: Color(0xFFDCE3EE),
    chalk: Color(0xFF0B111C),
    mist: Color(0xFF3F4B5E),
    muted: Color(0xFF6B7788),
    arctic: Color(0xFF2563EB),
    arcticDeep: Color(0xFF1D4ED8),
    arcticSoft: Color(0xFF3B82F6),
    glacier: Color(0xFF1E40AF),
    success: Color(0xFF2F8F55),
    warning: Color(0xFFB8781F),
    danger: Color(0xFFB4322A),
  );

  static AppPalette forBrightness(Brightness b) =>
      b == Brightness.dark ? dark : light;
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      AppPalette.forBrightness(Theme.of(this).brightness);
}
