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
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
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

