import 'package:flutter/material.dart';

/// NeedForNeeds design tokens — approved four-color palette.
///
/// Primary dark `#222831` · Secondary dark `#393E46` ·
/// Warm gray `#948979` · Cream `#DFD0B8`
///
/// Widgets must consume these tokens (or [ThemeData] / [ColorScheme]).
/// Do not hardcode hex colors in UI code.
class AppColors {
  const AppColors._();

  // ── Approved palette (source of truth) ─────────────────────────────────
  static const Color primaryDark = Color(0xFF222831);
  static const Color secondaryDark = Color(0xFF393E46);
  static const Color warmGray = Color(0xFF948979);
  static const Color cream = Color(0xFFDFD0B8);

  // ── Brand aliases ──────────────────────────────────────────────────────
  static const Color primary = primaryDark;
  static const Color primaryLight = secondaryDark;
  static const Color secondary = secondaryDark;
  static const Color accent = warmGray;
  static const Color surfaceAccent = cream;

  // ── Surfaces ───────────────────────────────────────────────────────────
  /// Warm cream app background.
  static const Color background = cream;

  /// Card / elevated surface — slightly lifted cream for hierarchy.
  static const Color surface = Color(0xFFEFE6D6);

  /// Muted panel / tonal fills.
  static const Color surfaceMuted = Color(0xFFE5D9C4);

  /// Borders & dividers (warm gray).
  static const Color border = warmGray;
  static const Color divider = warmGray;

  /// Chip / selected / highlight fill.
  static const Color chip = cream;

  // ── Text ───────────────────────────────────────────────────────────────
  /// Text/icons on dark primary surfaces.
  static const Color onPrimary = cream;
  static const Color onBackground = primaryDark;
  static const Color primaryText = primaryDark;
  static const Color secondaryText = warmGray;
  static const Color muted = warmGray;

  // ── Semantic (palette-derived for contrast) ────────────────────────────
  static const Color error = primaryDark;
  static const Color warning = warmGray;
  static const Color success = secondaryDark;

  static const Color errorSoft = Color(0xFFE8DFD0);
  static const Color warningSoft = Color(0xFFE5D9C4);
  static const Color successSoft = Color(0xFFE8DFD0);
  static const Color infoSoft = Color(0xFFE5D9C4);
  static const Color info = secondaryDark;

  // ── Inventory stock status ─────────────────────────────────────────────
  static const Color stockHealthy = secondaryDark;
  static const Color stockHealthyFg = secondaryDark;
  static const Color stockHealthyBg = successSoft;
  static const Color stockHealthyBorder = secondaryDark;

  static const Color stockLow = warmGray;
  static const Color stockLowFg = Color(0xFF6B6358);
  static const Color stockLowBg = warningSoft;
  static const Color stockLowBorder = warmGray;

  static const Color stockOut = primaryDark;
  static const Color stockOutFg = primaryDark;
  static const Color stockOutBg = errorSoft;
  static const Color stockOutBorder = primaryDark;

  // ── Locker / status extras ─────────────────────────────────────────────
  static const Color offlineBg = warningSoft;
  static const Color offlineFg = Color(0xFF6B6358);
  static const Color cancelBg = errorSoft;
  static const Color paidBg = infoSoft;
  static const Color paidFg = info;

  // ── Gradients ──────────────────────────────────────────────────────────
  static const List<Color> brandGradient = [primaryDark, secondaryDark];

  static const LinearGradient brandLinearGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brandGradient,
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, secondaryDark, warmGray],
  );

  static const LinearGradient lockerCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, surfaceMuted],
  );

  // ── Table / admin chrome ───────────────────────────────────────────────
  static const Color tableHeader = primaryDark;
  static const Color tableRowAlt = surfaceMuted;
  static const Color tableRowHover = Color(0xFFD9CDB8);
  static const Color tableBorder = warmGray;
  static const Color shadow = Color(0x33222831);

  // ── Dark mode surfaces ─────────────────────────────────────────────────
  static const Color darkBackground = primaryDark;
  static const Color darkSurface = secondaryDark;
  static const Color darkOnSurface = cream;
  static const Color darkMuted = warmGray;
}
