import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Material 3 light and dark theme configuration for the habit tracker.
abstract final class AppTheme {
  static ThemeData light() => _buildTheme(
        brightness: Brightness.light,
        scaffoldBackground: AppColors.lightBackground,
        palette: HabitPalette.light,
      );

  static ThemeData dark() => _buildTheme(
        brightness: Brightness.dark,
        scaffoldBackground: AppColors.darkBackground,
        palette: HabitPalette.dark,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackground,
    required HabitPalette palette,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.firePrimary,
      secondary: AppColors.coldPrimary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      extensions: [palette],
    );
  }
}
