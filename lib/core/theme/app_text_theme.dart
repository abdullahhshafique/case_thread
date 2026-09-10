import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design.md §2 typography. Base 16px; every named style maps to a usage
/// role defined there. Body text never uses weight below 400.
abstract final class AppTextTheme {
  static const String _inter = 'Inter';
  static const String _mono = 'JetBrainsMono';

  static TextTheme build() {
    return TextTheme(
      displayLarge: _style(32, FontWeight.w700),
      headlineLarge: _style(28, FontWeight.w700),
      headlineMedium: _style(22, FontWeight.w600),
      headlineSmall: _style(18, FontWeight.w600),
      bodyLarge: _style(16, FontWeight.w400),
      bodyMedium: _style(14, FontWeight.w400),
      labelMedium: _style(12, FontWeight.w500),
    );
  }

  /// Monospace for audit-log entries, file hashes, and code — anywhere exact
  /// character distinction matters (Design.md §2).
  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: _mono,
      fontSize: size,
      fontWeight: weight,
      color: AppColors.textPrimary,
      height: 1.5,
    );
  }

  static TextStyle _style(double size, FontWeight weight) {
    return TextStyle(
      fontFamily: _inter,
      fontSize: size,
      fontWeight: weight,
      color: AppColors.textPrimary,
      height: weight == FontWeight.w400 ? 1.5 : 1.3,
    );
  }
}
