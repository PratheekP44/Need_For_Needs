import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'nfn_tokens.dart';

/// NeedForNeeds Material 3 theme — maps the four-color palette into [ThemeData].
class AppTheme {
  const AppTheme._();

  static ColorScheme get _lightScheme => ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryDark,
        onPrimary: AppColors.cream,
        primaryContainer: AppColors.cream,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondaryDark,
        onSecondary: AppColors.cream,
        secondaryContainer: AppColors.surfaceMuted,
        onSecondaryContainer: AppColors.primaryDark,
        tertiary: AppColors.warmGray,
        onTertiary: AppColors.cream,
        tertiaryContainer: AppColors.cream,
        onTertiaryContainer: AppColors.primaryDark,
        error: AppColors.primaryDark,
        onError: AppColors.cream,
        errorContainer: AppColors.errorSoft,
        onErrorContainer: AppColors.primaryDark,
        surface: AppColors.surface,
        onSurface: AppColors.primaryDark,
        onSurfaceVariant: AppColors.warmGray,
        outline: AppColors.warmGray,
        outlineVariant: AppColors.warmGray.withValues(alpha: 0.45),
        shadow: AppColors.shadow,
        scrim: AppColors.primaryDark.withValues(alpha: 0.54),
        inverseSurface: AppColors.primaryDark,
        onInverseSurface: AppColors.cream,
        inversePrimary: AppColors.cream,
        surfaceTint: AppColors.secondaryDark,
      );

  static ColorScheme get _darkScheme => ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.cream,
        onPrimary: AppColors.primaryDark,
        primaryContainer: AppColors.secondaryDark,
        onPrimaryContainer: AppColors.cream,
        secondary: AppColors.warmGray,
        onSecondary: AppColors.primaryDark,
        secondaryContainer: AppColors.secondaryDark,
        onSecondaryContainer: AppColors.cream,
        tertiary: AppColors.warmGray,
        onTertiary: AppColors.cream,
        tertiaryContainer: AppColors.secondaryDark,
        onTertiaryContainer: AppColors.cream,
        error: AppColors.cream,
        onError: AppColors.primaryDark,
        errorContainer: AppColors.secondaryDark,
        onErrorContainer: AppColors.cream,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        onSurfaceVariant: AppColors.darkMuted,
        outline: AppColors.warmGray,
        outlineVariant: AppColors.warmGray.withValues(alpha: 0.4),
        shadow: AppColors.shadow,
        scrim: Colors.black54,
        inverseSurface: AppColors.cream,
        onInverseSurface: AppColors.primaryDark,
        inversePrimary: AppColors.secondaryDark,
        surfaceTint: AppColors.warmGray,
      );

  static ThemeData get light {
    final scheme = _lightScheme;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: AppColors.primaryText,
      displayColor: AppColors.primaryText,
    );

    return _buildTheme(
      brightness: Brightness.light,
      scheme: scheme,
      textTheme: textTheme,
      scaffoldBg: AppColors.background,
      canvasBg: AppColors.background,
      cardBg: AppColors.surface,
      appBarBg: AppColors.primaryDark,
      appBarFg: AppColors.cream,
      overlayStyle: SystemUiOverlayStyle.light,
      tokens: NfnTokens.light,
      buttonBg: AppColors.secondaryDark,
      buttonFg: AppColors.cream,
      chipBg: AppColors.cream,
      chipFg: AppColors.primaryDark,
      navBg: AppColors.surface,
      navIndicator: AppColors.cream,
      navSelected: AppColors.primaryDark,
      navUnselected: AppColors.warmGray,
      inputFill: AppColors.surface,
      progressColor: AppColors.secondaryDark,
      progressTrack: AppColors.surfaceMuted,
      snackBg: AppColors.primaryDark,
      snackFg: AppColors.cream,
      snackAction: AppColors.cream,
    );
  }

  static ThemeData get dark {
    final scheme = _darkScheme;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: AppColors.darkOnSurface,
      displayColor: AppColors.darkOnSurface,
    );

    return _buildTheme(
      brightness: Brightness.dark,
      scheme: scheme,
      textTheme: textTheme,
      scaffoldBg: AppColors.darkBackground,
      canvasBg: AppColors.darkBackground,
      cardBg: AppColors.darkSurface,
      appBarBg: AppColors.primaryDark,
      appBarFg: AppColors.cream,
      overlayStyle: SystemUiOverlayStyle.light,
      tokens: NfnTokens.dark,
      buttonBg: AppColors.secondaryDark,
      buttonFg: AppColors.cream,
      chipBg: AppColors.secondaryDark,
      chipFg: AppColors.cream,
      navBg: AppColors.darkSurface,
      navIndicator: AppColors.warmGray.withValues(alpha: 0.35),
      navSelected: AppColors.cream,
      navUnselected: AppColors.warmGray,
      inputFill: AppColors.darkSurface,
      progressColor: AppColors.cream,
      progressTrack: AppColors.secondaryDark,
      snackBg: AppColors.secondaryDark,
      snackFg: AppColors.cream,
      snackAction: AppColors.cream,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme scheme,
    required TextTheme textTheme,
    required Color scaffoldBg,
    required Color canvasBg,
    required Color cardBg,
    required Color appBarBg,
    required Color appBarFg,
    required SystemUiOverlayStyle overlayStyle,
    required NfnTokens tokens,
    required Color buttonBg,
    required Color buttonFg,
    required Color chipBg,
    required Color chipFg,
    required Color navBg,
    required Color navIndicator,
    required Color navSelected,
    required Color navUnselected,
    required Color inputFill,
    required Color progressColor,
    required Color progressTrack,
    required Color snackBg,
    required Color snackFg,
    required Color snackAction,
  }) {
    final radius14 = BorderRadius.circular(14);
    final radius16 = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: canvasBg,
      cardColor: cardBg,
      dividerColor: AppColors.warmGray,
      splashColor: AppColors.warmGray.withValues(alpha: 0.18),
      highlightColor: AppColors.warmGray.withValues(alpha: 0.10),
      hoverColor: AppColors.warmGray.withValues(alpha: 0.06),
      focusColor: AppColors.secondaryDark.withValues(alpha: 0.12),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      primaryIconTheme: IconThemeData(color: appBarFg),
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: appBarFg,
        ),
        iconTheme: IconThemeData(color: appBarFg),
        actionsIconTheme: IconThemeData(color: appBarFg),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius16,
          side: BorderSide(color: AppColors.warmGray.withValues(alpha: 0.55)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.warmGray,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBg,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: snackFg,
        ),
        actionTextColor: snackAction,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.warmGray,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.warmGray),
        prefixIconColor: AppColors.warmGray,
        suffixIconColor: AppColors.warmGray,
        border: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: AppColors.warmGray.withValues(alpha: 0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: AppColors.warmGray.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: const BorderSide(color: AppColors.primaryDark),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFill,
          border: OutlineInputBorder(
            borderRadius: radius14,
            borderSide: BorderSide(color: AppColors.warmGray.withValues(alpha: 0.7)),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(cardBg),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radius14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: buttonFg,
          disabledBackgroundColor: AppColors.warmGray.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.warmGray,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: buttonFg,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: AppColors.warmGray.withValues(alpha: 0.7)),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonBg,
        foregroundColor: buttonFg,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBg,
        selectedColor: AppColors.surfaceMuted,
        disabledColor: AppColors.warmGray.withValues(alpha: 0.25),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: chipFg,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: BorderSide(color: AppColors.warmGray.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        checkmarkColor: chipFg,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.primaryDark,
        textColor: AppColors.cream,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: progressColor,
        linearTrackColor: progressTrack,
        circularTrackColor: progressTrack,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.cream;
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondaryDark;
          }
          return AppColors.warmGray.withValues(alpha: 0.45);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return AppColors.warmGray;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondaryDark;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.cream),
        side: BorderSide(color: AppColors.warmGray, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondaryDark;
          }
          return AppColors.warmGray;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.secondaryDark,
        inactiveTrackColor: AppColors.surfaceMuted,
        thumbColor: AppColors.primaryDark,
        overlayColor: AppColors.warmGray.withValues(alpha: 0.16),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: AppColors.warmGray,
        indicatorColor: scheme.primary,
        dividerColor: AppColors.warmGray.withValues(alpha: 0.4),
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius14),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.warmGray.withValues(alpha: 0.55),
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.tableHeader),
        headingTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.cream,
          letterSpacing: 0.2,
        ),
        dataTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        dividerThickness: 1.2,
        headingRowHeight: 52,
        dataRowMinHeight: 64,
        dataRowMaxHeight: 76,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        indicatorColor: navIndicator,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? navSelected : navUnselected,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? navSelected : navUnselected,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBg,
        selectedItemColor: navSelected,
        unselectedItemColor: navUnselected,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius14),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: scheme.onSurface,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: AppColors.cream,
        ),
      ),
    );
  }
}
