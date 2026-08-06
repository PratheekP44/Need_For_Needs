import 'package:flutter/material.dart';

/// Dark engineering console palette for the Developer Dashboard.
abstract final class DevDashColors {
  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF121A2B);
  static const surfaceAlt = Color(0xFF1A2438);
  static const border = Color(0xFF2A3650);
  static const text = Color(0xFFE8EEF9);
  static const muted = Color(0xFF9AA8C7);
  static const accent = Color(0xFF3DDC97);
  static const accentBlue = Color(0xFF4C8DFF);
  static const warn = Color(0xFFFFC857);
  static const danger = Color(0xFFFF5C7A);
  static const grey = Color(0xFF6B778F);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentBlue,
        surface: surface,
        error: danger,
      ),
      scaffoldBackgroundColor: background,
      cardColor: surface,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surfaceAlt,
        side: BorderSide(color: border),
        labelStyle: TextStyle(color: text, fontSize: 12),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: text,
        displayColor: text,
      ),
    );
  }
}

Color boxStatusColor({
  required bool empty,
  required bool reserved,
  required bool busy,
  required String doorState,
  required String motorState,
}) {
  if (motorState == 'fault' || doorState == 'jammed') return DevDashColors.danger;
  if (busy || doorState == 'open') return DevDashColors.warn;
  if (reserved) return DevDashColors.accentBlue;
  if (empty) return DevDashColors.grey;
  return DevDashColors.accent;
}
