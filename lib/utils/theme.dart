// lib/utils/theme.dart

import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppCores.background,
      colorScheme: const ColorScheme.dark(
        surface: AppCores.surface,
        surfaceContainerHighest: AppCores.surfaceVariant,
        onSurface: AppCores.onSurface,
        onSurfaceVariant: AppCores.onSurfaceVariant,
        primary: AppCores.primary,
        primaryContainer: AppCores.primaryVariant,
        secondary: AppCores.amareloAlerta,
        error: AppCores.parada,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppCores.surface,
        foregroundColor: AppCores.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppCores.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppCores.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppCores.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppCores.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppCores.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppCores.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppCores.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppCores.primaryVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppCores.surfaceVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppCores.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppCores.parada),
        ),
        labelStyle: TextStyle(
          color: AppCores.onSurfaceVariant,
        ),
        hintStyle: TextStyle(
          color: AppCores.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppCores.surface,
        selectedItemColor: AppCores.primary,
        unselectedItemColor: AppCores.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppCores.surfaceVariant,
        selectedColor: AppCores.primary,
        labelStyle: const TextStyle(
          color: AppCores.onSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppCores.surfaceVariant,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppCores.onBackground,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppCores.onBackground,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppCores.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppCores.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppCores.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppCores.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppCores.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppCores.onSurface,
        ),
      ),
    );
  }

  static const Color corFundo = AppCores.background;
  static const Color corSuperficie = AppCores.surface;
  static const Color corPrimaria = AppCores.primary;
  static const Color corAlerta = AppCores.amareloAlerta;
}