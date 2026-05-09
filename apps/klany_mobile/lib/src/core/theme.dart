import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Force consistent Material Design on all platforms (iOS + Android look identical).
const _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
    TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
  },
);

ThemeData _build(ColorScheme colorScheme) {
  final base = ThemeData(
    useMaterial3: true,
    platform: TargetPlatform.android, // widgets look same on iOS and Android
    colorScheme: colorScheme,
    pageTransitionsTheme: _pageTransitions,
  );

  return base.copyWith(
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme),
    primaryTextTheme: GoogleFonts.manropeTextTheme(base.primaryTextTheme),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    // Make Scaffold transparent so the global cloud background shows through.
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF1E2D52),
      ),
    ),
    // Soft 3D-style shadow under all FilledButtons.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.18)),
        textStyle: WidgetStatePropertyAll(GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        )),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        elevation: const WidgetStatePropertyAll(2),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.10)),
        textStyle: WidgetStatePropertyAll(GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        )),
      ),
    ),
    // Consistent text field border on both platforms.
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    // Remove iOS extra bottom padding from NavigationBar.
    navigationBarTheme: const NavigationBarThemeData(
      height: 64,
    ),
    // Consistent card shape.
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
    ),
  );
}

class AppTheme {
  static ThemeData light() => _build(
        ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ),
      );
}

