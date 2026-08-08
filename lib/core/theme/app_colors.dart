import 'package:flutter/material.dart';

/// NeedForNeeds design tokens — single source of truth for brand colors.
///
/// Widgets must consume these tokens (or [ThemeData] / [ColorScheme] mapped
/// from them). Do not hardcode hex colors in UI code.
class AppColors {
  const AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────
  /// Primary brand red-orange.
  static const Color primary = Color(0xFFE73F1E);

  /// Warm orange used for secondary emphasis / lighter brand stops.
  static const Color primaryLight = Color(0xFFFB6C00);

  /// Secondary brand orange.
  static const Color secondary = Color(0xFFFB6C00);

  /// Accent gold.
  static const Color accent = Color(0xFFF9B637);

  /// Soft surface accent (chips, highlights).
  static const Color surfaceAccent = Color(0xFFFFDD9C);

  // ── Surfaces ───────────────────────────────────────────────────────────
  /// App background warm cream.
  static const Color background = Color(0xFFFFF9F3);

  /// Card / elevated surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Muted warm panel / tonal button fill.
  static const Color surfaceMuted = Color(0xFFFFF0E0);

  /// Dividers and borders.
  static const Color border = Color(0xFFF1E6D8);

  /// Alias for divider token.
  static const Color divider = border;

  /// Default chip fill.
  static const Color chip = surfaceAccent;

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF1F1F1F);
  static const Color primaryText = onBackground;
  static const Color secondaryText = Color(0xFF666666);
  static const Color muted = secondaryText;

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFF9B637);
  static const Color success = Color(0xFF2E7D32);

  // Soft semantic fills (chips / badges) — paired with dark foregrounds for AA.
  static const Color errorSoft = Color(0xFFFFEBEE);
  static const Color warningSoft = Color(0xFFFFF3D6);
  static const Color successSoft = Color(0xFFE8F5E9);
  static const Color infoSoft = Color(0xFFFFE8D6);
  static const Color info = Color(0xFFB45309);

  // ── Inventory stock status ─────────────────────────────────────────────
  /// Healthy / in stock — green.
  static const Color stockHealthy = success;
  static const Color stockHealthyFg = Color(0xFF1B5E20);
  static const Color stockHealthyBg = successSoft;
  static const Color stockHealthyBorder = Color(0xFF2E7D32);

  /// Low stock — gold.
  static const Color stockLow = accent;
  static const Color stockLowFg = Color(0xFF7A5200);
  static const Color stockLowBg = Color(0xFFFFF0C2);
  static const Color stockLowBorder = Color(0xFFD4A017);

  /// Out of stock — red.
  static const Color stockOut = error;
  static const Color stockOutFg = Color(0xFFB71C1C);
  static const Color stockOutBg = errorSoft;
  static const Color stockOutBorder = Color(0xFFC62828);

  // ── Locker / status extras ─────────────────────────────────────────────
  static const Color offlineBg = warningSoft;
  static const Color offlineFg = Color(0xFF7A5A00);
  static const Color cancelBg = errorSoft;
  static const Color paidBg = infoSoft;
  static const Color paidFg = info;

  // ── Gradients ──────────────────────────────────────────────────────────
  /// Admin statistic cards & brand CTAs: primary → secondary.
  static const List<Color> brandGradient = [primary, secondary];

  static const LinearGradient brandLinearGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brandGradient,
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight, accent],
  );

  static const LinearGradient lockerCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, surfaceMuted],
  );

  // ── Table / admin chrome ───────────────────────────────────────────────
  static const Color tableHeader = primary;
  static const Color tableRowAlt = Color(0xFFFFF5EB);
  static const Color tableRowHover = Color(0xFFFFE8D1);
  static const Color tableBorder = Color(0xFFE8D5C0);
  static const Color shadow = Color(0x1A1F1F1F);
}
