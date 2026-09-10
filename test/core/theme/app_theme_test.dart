import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/theme/app_colors.dart';
import 'package:case_thread/core/theme/app_spacing.dart';
import 'package:case_thread/core/theme/app_text_theme.dart';
import 'package:case_thread/core/theme/app_theme.dart';

/// Guards the Design.md token contract: if a token value drifts, this test
/// fails before a UI review can catch it.
void main() {
  group('AppColors match Design.md §1', () {
    test('background tokens', () {
      expect(AppColors.bgPrimary, const Color(0xFF0B1220));
      expect(AppColors.bgSurface, const Color(0xFF1B2436));
      expect(AppColors.bgSurfaceRaised, const Color(0xFF242F45));
      expect(AppColors.borderSubtle, const Color(0xFF2E3A52));
    });

    test('text and accent tokens', () {
      expect(AppColors.textPrimary, const Color(0xFFEDEFF3));
      expect(AppColors.textSecondary, const Color(0xFF8B96AB));
      expect(AppColors.accentPrimary, const Color(0xFF4FA8A0));
      expect(AppColors.accentPrimaryHover, const Color(0xFF63BDB4));
    });

    test('state tokens — amber reserved for AI suggestions only', () {
      expect(AppColors.statePending, const Color(0xFFE8B04B));
      expect(AppColors.stateSuccess, const Color(0xFF5FBF7A));
      expect(AppColors.stateError, const Color(0xFFE06767));
    });
  });

  group('Theme wiring', () {
    final theme = buildAppTheme();

    test('is dark-first per Design.md §10', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.bgPrimary);
    });

    test('primary color is the teal accent', () {
      expect(theme.colorScheme.primary, AppColors.accentPrimary);
    });

    test('base font is Inter', () {
      expect(theme.textTheme.bodyLarge!.fontFamily, 'Inter');
      expect(theme.textTheme.headlineSmall!.fontFamily, 'Inter');
    });

    test('body text never below weight 400 (Design.md §2)', () {
      final body = theme.textTheme.bodyLarge!;
      expect(body.fontWeight, FontWeight.w400);
      expect(body.fontSize, 16);
    });

    test('type scale sizes match the table', () {
      expect(theme.textTheme.displayLarge!.fontSize, 32);
      expect(theme.textTheme.headlineLarge!.fontSize, 28);
      expect(theme.textTheme.headlineMedium!.fontSize, 22);
      expect(theme.textTheme.headlineSmall!.fontSize, 18);
      expect(theme.textTheme.bodyMedium!.fontSize, 14);
      expect(theme.textTheme.labelMedium!.fontSize, 12);
    });

    test('mono helper uses JetBrains Mono', () {
      final mono = AppTextTheme.mono();
      expect(mono.fontFamily, 'JetBrainsMono');
    });
  });

  group('Spacing scale (Design.md §4)', () {
    test('is the 4px scale', () {
      expect(AppSpacing.xxs, 4);
      expect(AppSpacing.xs, 8);
      expect(AppSpacing.sm, 12);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.lg, 24);
      expect(AppSpacing.xl, 32);
      expect(AppSpacing.xxl, 48);
      expect(AppSpacing.xxxl, 64);
    });

    test('breakpoints match the table', () {
      expect(AppBreakpoints.mobile, 600);
      expect(AppBreakpoints.tablet, 1024);
      expect(AppBreakpoints.desktop, 1440);
    });
  });
}
