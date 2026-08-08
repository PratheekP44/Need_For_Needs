import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme extension exposing NeedForNeeds custom tokens beyond [ColorScheme].
@immutable
class NfnTokens extends ThemeExtension<NfnTokens> {
  const NfnTokens({
    required this.surfaceAccent,
    required this.surfaceMuted,
    required this.primaryText,
    required this.secondaryText,
    required this.divider,
    required this.success,
    required this.warning,
    required this.stockHealthy,
    required this.stockHealthyBg,
    required this.stockHealthyFg,
    required this.stockLow,
    required this.stockLowBg,
    required this.stockLowFg,
    required this.stockOut,
    required this.stockOutBg,
    required this.stockOutFg,
    required this.brandGradient,
  });

  final Color surfaceAccent;
  final Color surfaceMuted;
  final Color primaryText;
  final Color secondaryText;
  final Color divider;
  final Color success;
  final Color warning;
  final Color stockHealthy;
  final Color stockHealthyBg;
  final Color stockHealthyFg;
  final Color stockLow;
  final Color stockLowBg;
  final Color stockLowFg;
  final Color stockOut;
  final Color stockOutBg;
  final Color stockOutFg;
  final List<Color> brandGradient;

  static const light = NfnTokens(
    surfaceAccent: AppColors.surfaceAccent,
    surfaceMuted: AppColors.surfaceMuted,
    primaryText: AppColors.primaryText,
    secondaryText: AppColors.secondaryText,
    divider: AppColors.divider,
    success: AppColors.success,
    warning: AppColors.warning,
    stockHealthy: AppColors.stockHealthy,
    stockHealthyBg: AppColors.stockHealthyBg,
    stockHealthyFg: AppColors.stockHealthyFg,
    stockLow: AppColors.stockLow,
    stockLowBg: AppColors.stockLowBg,
    stockLowFg: AppColors.stockLowFg,
    stockOut: AppColors.stockOut,
    stockOutBg: AppColors.stockOutBg,
    stockOutFg: AppColors.stockOutFg,
    brandGradient: AppColors.brandGradient,
  );

  @override
  NfnTokens copyWith({
    Color? surfaceAccent,
    Color? surfaceMuted,
    Color? primaryText,
    Color? secondaryText,
    Color? divider,
    Color? success,
    Color? warning,
    Color? stockHealthy,
    Color? stockHealthyBg,
    Color? stockHealthyFg,
    Color? stockLow,
    Color? stockLowBg,
    Color? stockLowFg,
    Color? stockOut,
    Color? stockOutBg,
    Color? stockOutFg,
    List<Color>? brandGradient,
  }) {
    return NfnTokens(
      surfaceAccent: surfaceAccent ?? this.surfaceAccent,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      stockHealthy: stockHealthy ?? this.stockHealthy,
      stockHealthyBg: stockHealthyBg ?? this.stockHealthyBg,
      stockHealthyFg: stockHealthyFg ?? this.stockHealthyFg,
      stockLow: stockLow ?? this.stockLow,
      stockLowBg: stockLowBg ?? this.stockLowBg,
      stockLowFg: stockLowFg ?? this.stockLowFg,
      stockOut: stockOut ?? this.stockOut,
      stockOutBg: stockOutBg ?? this.stockOutBg,
      stockOutFg: stockOutFg ?? this.stockOutFg,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  NfnTokens lerp(ThemeExtension<NfnTokens>? other, double t) {
    if (other is! NfnTokens) return this;
    return NfnTokens(
      surfaceAccent: Color.lerp(surfaceAccent, other.surfaceAccent, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      stockHealthy: Color.lerp(stockHealthy, other.stockHealthy, t)!,
      stockHealthyBg: Color.lerp(stockHealthyBg, other.stockHealthyBg, t)!,
      stockHealthyFg: Color.lerp(stockHealthyFg, other.stockHealthyFg, t)!,
      stockLow: Color.lerp(stockLow, other.stockLow, t)!,
      stockLowBg: Color.lerp(stockLowBg, other.stockLowBg, t)!,
      stockLowFg: Color.lerp(stockLowFg, other.stockLowFg, t)!,
      stockOut: Color.lerp(stockOut, other.stockOut, t)!,
      stockOutBg: Color.lerp(stockOutBg, other.stockOutBg, t)!,
      stockOutFg: Color.lerp(stockOutFg, other.stockOutFg, t)!,
      brandGradient: t < 0.5 ? brandGradient : other.brandGradient,
    );
  }
}

/// Convenience accessors for theme colors.
extension NfnThemeContext on BuildContext {
  ThemeData get nfnTheme => Theme.of(this);

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  NfnTokens get nfnTokens =>
      Theme.of(this).extension<NfnTokens>() ?? NfnTokens.light;
}
