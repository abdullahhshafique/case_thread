import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_theme.dart';

/// Dark theme per Design.md §1–§7.
///
/// MVP is dark-only and this IS the default experience (Design.md §10), built
/// entirely from named tokens so a light theme can later reuse the same token
/// names with different values.
///
/// Pass [brightness] to enable the light theme (Phase 1 PRD). The helper
/// extracts all shared styling so both palettes are built from one path.
ThemeData buildAppTheme({Brightness brightness = Brightness.dark}) {
  final text = AppTextTheme.build(
    primaryColor: brightness == Brightness.dark
        ? AppColors.textPrimary
        : AppColorsLight.textPrimary,
    secondaryColor: brightness == Brightness.dark
        ? AppColors.textSecondary
        : AppColorsLight.textSecondary,
  );
  return _buildTheme(
    brightness: brightness,
    textTheme: text,
    colorScheme: brightness == Brightness.dark
        ? const ColorScheme.dark(
            primary: AppColors.accentPrimary,
            onPrimary: AppColors.bgPrimary,
            secondary: AppColors.accentPrimaryHover,
            onSecondary: AppColors.bgPrimary,
            surface: AppColors.bgSurface,
            onSurface: AppColors.textPrimary,
            error: AppColors.stateError,
            onError: AppColors.bgPrimary,
          )
        : const ColorScheme.light(
            primary: AppColorsLight.accentPrimary,
            onPrimary: AppColorsLight.bgPrimary,
            secondary: AppColorsLight.accentPrimaryHover,
            onSecondary: AppColorsLight.bgPrimary,
            surface: AppColorsLight.bgSurface,
            onSurface: AppColorsLight.textPrimary,
            error: AppColorsLight.stateError,
            onError: AppColorsLight.bgPrimary,
          ),
  );
}

ThemeData _buildTheme({
  required Brightness brightness,
  required TextTheme textTheme,
  required ColorScheme colorScheme,
}) {
  final isDark = brightness == Brightness.dark;
  final bgPrimary = isDark ? AppColors.bgPrimary : AppColorsLight.bgPrimary;
  final bgSurface = isDark ? AppColors.bgSurface : AppColorsLight.bgSurface;
  final bgSurfaceRaised = isDark
      ? AppColors.bgSurfaceRaised
      : AppColorsLight.bgSurfaceRaised;
  final textPrimary = isDark
      ? AppColors.textPrimary
      : AppColorsLight.textPrimary;
  final textSecondary = isDark
      ? AppColors.textSecondary
      : AppColorsLight.textSecondary;
  final accentPrimary = isDark
      ? AppColors.accentPrimary
      : AppColorsLight.accentPrimary;
  final accentPrimaryHover = isDark
      ? AppColors.accentPrimaryHover
      : AppColorsLight.accentPrimaryHover;
  final borderSubtle = isDark
      ? AppColors.borderSubtle
      : AppColorsLight.borderSubtle;
  final consoleText = isDark
      ? AppColors.consoleText
      : AppColorsLight.consoleText;
  final consoleMuted = isDark
      ? AppColors.consoleMuted
      : AppColorsLight.consoleMuted;
  final brandBlue = isDark ? AppColors.brandBlue : AppColorsLight.brandBlue;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: bgPrimary,
    textTheme: textTheme,
    fontFamily: 'Geist',
    splashFactory: NoSplash.splashFactory,
    dividerColor: borderSubtle,
    dividerTheme: DividerThemeData(color: borderSubtle, thickness: 1),
    // Focus ring: 2px teal, never removed without replacement (Design.md §11).
    focusColor: accentPrimary.withValues(alpha: 0.25),
  ).copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bgPrimary,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Geist',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: textPrimary,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: bgSurfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        side: BorderSide(color: borderSubtle),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: consoleText,
      unselectedLabelColor: consoleMuted,
      dividerColor: Colors.transparent,
      indicatorColor: brandBlue,
    ),
    inputDecorationTheme: _inputDecoration(
      bgSurface: bgSurface,
      borderSubtle: borderSubtle,
      accentPrimary: accentPrimary,
      textSecondary: textSecondary,
    ),
    elevatedButtonTheme: _elevatedButton(
      bgSurfaceRaised: bgSurfaceRaised,
      accentPrimary: accentPrimary,
      accentPrimaryHover: accentPrimaryHover,
      textSecondary: textSecondary,
      bgPrimary: bgPrimary,
    ),
    outlinedButtonTheme: _outlinedButton(
      accentPrimary: accentPrimary,
      borderSubtle: borderSubtle,
    ),
    textButtonTheme: _textButton(accentPrimary: accentPrimary),
    cardTheme: _card(bgSurface: bgSurface, borderSubtle: borderSubtle),
    snackBarTheme: _snackBar(
      bgSurfaceRaised: bgSurfaceRaised,
      textPrimary: textPrimary,
    ),
    navigationBarTheme: _navigationBar(
      bgSurface: bgSurface,
      accentPrimary: accentPrimary,
      textSecondary: textSecondary,
      textTheme: textTheme,
    ),
    navigationRailTheme: _navigationRail(
      bgSurface: bgSurface,
      accentPrimary: accentPrimary,
      bgPrimary: bgPrimary,
      textSecondary: textSecondary,
    ),
  );
}

InputDecorationTheme _inputDecoration({
  required Color bgSurface,
  required Color borderSubtle,
  required Color accentPrimary,
  required Color textSecondary,
}) {
  const radius = BorderRadius.all(Radius.circular(12));
  return InputDecorationTheme(
    filled: true,
    fillColor: bgSurface,
    hintStyle: TextStyle(color: textSecondary),
    labelStyle: TextStyle(color: textSecondary),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: borderSubtle),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: borderSubtle),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: accentPrimary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.stateError, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.stateError, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  );
}

ElevatedButtonThemeData _elevatedButton({
  required Color bgSurfaceRaised,
  required Color accentPrimary,
  required Color accentPrimaryHover,
  required Color textSecondary,
  required Color bgPrimary,
}) {
  // Primary action button: teal fill (Design.md §6 Button — Primary).
  // State-resolved colors handle the disabled variant (hover via overlay).
  return ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? bgSurfaceRaised
            : accentPrimary,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? textSecondary : bgPrimary,
      ),
      overlayColor: WidgetStatePropertyAll(accentPrimaryHover),
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Geist',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );
}

OutlinedButtonThemeData _outlinedButton({
  required Color accentPrimary,
  required Color borderSubtle,
}) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: accentPrimary,
      side: BorderSide(color: borderSubtle),
      minimumSize: const Size(64, 48),
      textStyle: const TextStyle(
        fontFamily: 'Geist',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}

TextButtonThemeData _textButton({required Color accentPrimary}) {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: accentPrimary,
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(
        fontFamily: 'Geist',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

CardThemeData _card({required Color bgSurface, required Color borderSubtle}) {
  return CardThemeData(
    color: bgSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      side: BorderSide(color: borderSubtle),
    ),
    margin: EdgeInsets.zero,
  );
}

SnackBarThemeData _snackBar({
  required Color bgSurfaceRaised,
  required Color textPrimary,
}) {
  return SnackBarThemeData(
    backgroundColor: bgSurfaceRaised,
    contentTextStyle: TextStyle(
      fontFamily: 'Geist',
      fontSize: 14,
      color: textPrimary,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  );
}

NavigationBarThemeData _navigationBar({
  required Color bgSurface,
  required Color accentPrimary,
  required Color textSecondary,
  required TextTheme textTheme,
}) {
  // Mobile shell: bottom tab bar (Design.md §12).
  return NavigationBarThemeData(
    backgroundColor: bgSurface,
    indicatorColor: accentPrimary.withValues(alpha: 0.15),
    labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    iconTheme: WidgetStatePropertyAll(IconThemeData(color: textSecondary)),
  );
}

NavigationRailThemeData _navigationRail({
  required Color bgSurface,
  required Color accentPrimary,
  required Color bgPrimary,
  required Color textSecondary,
}) {
  // Tablet/desktop shell: sidebar (Design.md §12).
  return NavigationRailThemeData(
    backgroundColor: bgSurface,
    indicatorColor: accentPrimary,
    selectedIconTheme: IconThemeData(color: bgPrimary),
    unselectedIconTheme: IconThemeData(color: textSecondary),
  );
}
