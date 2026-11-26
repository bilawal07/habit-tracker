import 'package:flutter/material.dart';

/// Fire and Cold palette used across light and dark Material 3 themes.
abstract final class AppColors {
  // Hot Fire tones
  static const Color firePrimary = Color(0xFFFF5722);
  static const Color fireAccent = Color(0xFFFF9800);
  static const Color fireDeep = Color(0xFFD84315);
  static const Color fireSurface = Color(0xFFFFF3E0);
  static const Color fireSurfaceDark = Color(0xFF331B12);

  // Cold / Ice tones
  static const Color coldPrimary = Color(0xFF0288D1);
  static const Color coldAccent = Color(0xFF4FC3F7);
  static const Color coldDeep = Color(0xFF01579B);
  static const Color coldSurface = Color(0xFFE1F5FE);
  static const Color coldSurfaceDark = Color(0xFF0F2533);

  // Neutral & status tones
  static const Color success = Color(0xFF2E7D32);
  static const Color locked = Color(0xFF9E9E9E);
  static const Color lightBackground = Color(0xFFFAF9F7);
  static const Color darkBackground = Color(0xFF121316);
}

/// Custom theme extension exposing semantic Fire/Cold colors to widgets.
@immutable
class HabitPalette extends ThemeExtension<HabitPalette> {
  const HabitPalette({
    required this.fire,
    required this.fireContainer,
    required this.cold,
    required this.coldContainer,
    required this.done,
    required this.locked,
  });

  final Color fire;
  final Color fireContainer;
  final Color cold;
  final Color coldContainer;
  final Color done;
  final Color locked;

  static const light = HabitPalette(
    fire: AppColors.firePrimary,
    fireContainer: AppColors.fireSurface,
    cold: AppColors.coldPrimary,
    coldContainer: AppColors.coldSurface,
    done: AppColors.success,
    locked: AppColors.locked,
  );

  static const dark = HabitPalette(
    fire: AppColors.fireAccent,
    fireContainer: AppColors.fireSurfaceDark,
    cold: AppColors.coldAccent,
    coldContainer: AppColors.coldSurfaceDark,
    done: Color(0xFF66BB6A),
    locked: Color(0xFF757575),
  );

  @override
  HabitPalette copyWith({
    Color? fire,
    Color? fireContainer,
    Color? cold,
    Color? coldContainer,
    Color? done,
    Color? locked,
  }) {
    return HabitPalette(
      fire: fire ?? this.fire,
      fireContainer: fireContainer ?? this.fireContainer,
      cold: cold ?? this.cold,
      coldContainer: coldContainer ?? this.coldContainer,
      done: done ?? this.done,
      locked: locked ?? this.locked,
    );
  }

  @override
  HabitPalette lerp(ThemeExtension<HabitPalette>? other, double t) {
    if (other is! HabitPalette) return this;
    return HabitPalette(
      fire: Color.lerp(fire, other.fire, t)!,
      fireContainer: Color.lerp(fireContainer, other.fireContainer, t)!,
      cold: Color.lerp(cold, other.cold, t)!,
      coldContainer: Color.lerp(coldContainer, other.coldContainer, t)!,
      done: Color.lerp(done, other.done, t)!,
      locked: Color.lerp(locked, other.locked, t)!,
    );
  }
}
