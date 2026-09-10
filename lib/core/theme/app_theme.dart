import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_theme.dart';

/// Dark theme per Design.md §1–§7.
///
/// MVP is dark-only and this IS the default experience (Design.md §10), built
/// entirely from named tokens so a light theme can later reuse the same token
/// names with different values.
ThemeData buildAppTheme() {
  final text = AppTextTheme.build();
  final colorScheme = const ColorScheme.dark(
    primary: AppColors.accentPrimary,
    onPrimary: AppColors.bgPrimary,
    secondary: AppColors.accentPrimaryHover,
    onSecondary: AppColors.bgPrimary,
    surface: AppColors.bgSurface,
    onSurface: AppColors.textPrimary,
    error: AppColors.stateError,
    onError: AppColors.bgPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    textTheme: text,
    fontFamily: 'Inter',
    splashFactory: NoSplash.splashFactory,
    dividerColor: AppColors.borderSubtle,
    dividerTheme: const DividerThemeData(
      color: AppColors.borderSubtle,
      thickness: 1,
    ),
    // Focus ring: 2px teal, never removed without replacement (Design.md §11).
    focusColor: AppColors.accentPrimary.withValues(alpha: 0.25),
  ).copyWith(
    inputDecorationTheme: _inputDecoration(),
    elevatedButtonTheme: _elevatedButton(),
    outlinedButtonTheme: _outlinedButton(),
    textButtonTheme: _textButton(),
    cardTheme: _card(),
    snackBarTheme: _snackBar(),
    navigationBarTheme: _navigationBar(),
    navigationRailTheme: _navigationRail(),
  );
}

InputDecorationTheme _inputDecoration() {
  const radius = BorderRadius.all(Radius.circular(8));
  return InputDecorationTheme(
    filled: true,
    fillColor: AppColors.bgSurface,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.borderSubtle),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.borderSubtle),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.accentPrimary, width: 2),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.stateError, width: 2),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.stateError, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  );
}

ElevatedButtonThemeData _elevatedButton() {
  // Primary action button: teal fill (Design.md §6 Button — Primary).
  // State-resolved colors handle the disabled variant (hover via overlay).
  return ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.bgSurfaceRaised
            : AppColors.accentPrimary,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.textSecondary
            : AppColors.bgPrimary,
      ),
      overlayColor: const WidgetStatePropertyAll(AppColors.accentPrimaryHover),
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    ),
  );
}

OutlinedButtonThemeData _outlinedButton() {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accentPrimary,
      side: const BorderSide(color: AppColors.borderSubtle),
      minimumSize: const Size(64, 48),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
}

TextButtonThemeData _textButton() {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accentPrimary,
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

CardThemeData _card() {
  return const CardThemeData(
    color: AppColors.bgSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      side: BorderSide(color: AppColors.borderSubtle),
    ),
    margin: EdgeInsets.zero,
  );
}

SnackBarThemeData _snackBar() {
  return const SnackBarThemeData(
    backgroundColor: AppColors.bgSurfaceRaised,
    contentTextStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      color: AppColors.textPrimary,
    ),
    behavior: SnackBarBehavior.floating,
  );
}

NavigationBarThemeData _navigationBar() {
  // Mobile shell: bottom tab bar (Design.md §12).
  return NavigationBarThemeData(
    backgroundColor: AppColors.bgSurface,
    indicatorColor: AppColors.accentPrimary.withValues(alpha: 0.15),
    labelTextStyle: WidgetStatePropertyAll(AppTextTheme.build().labelMedium),
    iconTheme: const WidgetStatePropertyAll(
      IconThemeData(color: AppColors.textSecondary),
    ),
  );
}

NavigationRailThemeData _navigationRail() {
  // Tablet/desktop shell: sidebar (Design.md §12).
  return const NavigationRailThemeData(
    backgroundColor: AppColors.bgSurface,
    indicatorColor: AppColors.accentPrimary,
    selectedIconTheme: IconThemeData(color: AppColors.bgPrimary),
    unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
  );
}
