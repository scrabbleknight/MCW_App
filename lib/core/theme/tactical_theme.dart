import 'package:flutter/material.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

class TacticalTheme {
  TacticalTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: TacticalPalette.arctic,
      brightness: Brightness.dark,
    ).copyWith(
      surface: TacticalPalette.midnight,
      onSurface: TacticalPalette.chalk,
      primary: TacticalPalette.arctic,
      onPrimary: Colors.white,
      secondary: TacticalPalette.arcticSoft,
      surfaceContainerHighest: TacticalPalette.surfaceHigh,
      outline: TacticalPalette.hairline,
    );

    final text = base.textTheme.apply(
      bodyColor: TacticalPalette.chalk,
      displayColor: TacticalPalette.chalk,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: TacticalPalette.abyss,
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: TacticalPalette.chalk,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TacticalPalette.arctic,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: TacticalPalette.arcticSoft),
      ),
    );
  }
}
