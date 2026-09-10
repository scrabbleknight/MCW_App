import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:military_calisthenics_women/core/theme/tactical_palette.dart';

class TacticalTheme {
  TacticalTheme._();

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette p, Brightness b) {
    final base = b == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final scheme = ColorScheme.fromSeed(
      seedColor: p.arctic,
      brightness: b,
    ).copyWith(
      surface: p.midnight,
      onSurface: p.chalk,
      primary: p.arctic,
      onPrimary: Colors.white,
      secondary: p.arcticSoft,
      surfaceContainerHighest: p.surfaceHigh,
      outline: p.hairline,
    );

    final text = base.textTheme.apply(
      bodyColor: p.chalk,
      displayColor: p.chalk,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: p.abyss,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.chalk,
        elevation: 0,
        centerTitle: false,
        // Match status-bar icon colour to the app ground so time/battery
        // stay visible in both themes. iOS ignores statusBarColor.
        systemOverlayStyle: b == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.arctic,
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
        style: TextButton.styleFrom(foregroundColor: p.arcticSoft),
      ),
    );
  }
}
