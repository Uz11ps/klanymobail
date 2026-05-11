import 'package:flutter/material.dart';

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
    fontFamily: 'Nunito',
  );

  return base.copyWith(
    // Global default font for any text without an explicit family.
    textTheme: base.textTheme.apply(fontFamily: 'Nunito'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Nunito'),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    // Make Scaffold transparent so the global cloud background shows through.
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: Color(0xFF1E2D52),
      ),
    ),
    // App-style FilledButton: mint, dark ink text, hard bottom shadow.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Color(0xFFC5F2C0)),
        foregroundColor: const WidgetStatePropertyAll(Color(0xFF1F4F1B)),
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(54)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: const WidgetStatePropertyAll(Color(0xFF7BC976)),
        textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          fontWeight: FontWeight.w800,
        )),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Color(0xFFD7E1F2), width: 1.4),
        ),
        textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: 'Nunito',
          fontSize: 15,
          fontWeight: FontWeight.w800,
        )),
      ),
    ),
    // Soft white pill input fields with subtle border, rounded 22.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: Color(0xFF5B6B85), fontSize: 14),
      labelStyle: const TextStyle(color: Color(0xFF5B6B85), fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF1E2D52),
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFD7E1F2), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFD7E1F2), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFF1A4BBF), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFD83A3A), width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFD83A3A), width: 1.6),
      ),
    ),
    // Checkbox + Switch — match brand blue
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: Color(0xFFD7E1F2), width: 1.4),
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF1A4BBF)
              : Colors.white),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF1A4BBF)
              : const Color(0xFFD7E1F2)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFC5F2C0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFD7E1F2), width: 1.2),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E2D52),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
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

