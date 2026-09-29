import 'package:flutter/material.dart';

/// Couleurs de Mano : vert forêt, vert citron, fond clair.
abstract final class ManoColors {
  static const forest = Color(0xFF1E4D3B);
  static const forestLight = Color(0xFF2E6250);
  static const lime = Color(0xFFD4EC7C);
  static const background = Color(0xFFF2F4EF);
}

ThemeData manoTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ManoColors.forest,
    primary: ManoColors.forest,
    secondary: ManoColors.lime,
    onSecondary: ManoColors.forest,
    surface: ManoColors.background,
    // Cartes de résumé (valeur du stock, dettes, bilan) : vert forêt.
    primaryContainer: ManoColors.forest,
    onPrimaryContainer: Colors.white,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: ManoColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: ManoColors.background,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: rounded),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: ManoColors.lime,
      foregroundColor: ManoColors.forest,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
