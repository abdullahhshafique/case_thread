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
    test('background tokens (canonical v3 console surfaces, §16.3)', () {
      expect(AppColors.bgPrimary, const Color(0xFF05060A));
      expect(AppColors.bgSurface, const Color(0xFF0B0D14));
      expect(AppColors.bgSurfaceRaised, const Color(0xFF10131D));
      expect(AppColors.borderSubtle, const Color(0x17FFFFFF));
    });

    test('text and accent tokens (v3: brand blue accent)', () {
      expect(AppColors.textPrimary, const Color(0xFFF7F8FC));
      expect(AppColors.textSecondary, const Color(0xFF9AA2B6));
      expect(AppColors.accentPrimary, const Color(0xFF3D71FF));
      expect(AppColors.accentPrimaryHover, const Color(0xFF6B8BFF));
    });

    test('state tokens — amber = attention/partial, always labeled', () {
      expect(AppColors.statePending, const Color(0xFFE1A66B));
      expect(AppColors.stateSuccess, const Color(0xFF4EE3B8));
      expect(AppColors.stateError, const Color(0xFFD5666C));
    });

    test('semantic status tokens (Design.md v2 §1.3)', () {
      expect(AppColors.statusOpen, const Color(0xFF6193FF));
      expect(AppColors.statusGap, const Color(0xFFB98AE0));
      expect(AppColors.statusNeutral, const Color(0xFF8C99A8));
      expect(AppColors.bgMintTint, const Color(0xFF122C2D));
      expect(AppColors.chatBubbleOwn, const Color(0xFF1E4C44));
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

    test('base font is Geist (v3 console §0)', () {
      expect(theme.textTheme.bodyLarge!.fontFamily, 'Geist');
      expect(theme.textTheme.headlineSmall!.fontFamily, 'Geist');
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

    test('mono helper uses Geist Mono (v3 console §0)', () {
      final mono = AppTextTheme.mono();
      expect(mono.fontFamily, 'GeistMono');
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

  group('Light theme (Phase 1 PRD)', () {
    final light = buildAppTheme(brightness: Brightness.light);

    test('brightness is light', () {
      expect(light.brightness, Brightness.light);
    });

    test('scaffold uses light bgPrimary', () {
      expect(light.scaffoldBackgroundColor, AppColorsLight.bgPrimary);
    });

    test('colorScheme primary uses light accentPrimary', () {
      expect(light.colorScheme.primary, AppColorsLight.accentPrimary);
    });

    test('text colors are dark for contrast on light surfaces', () {
      expect(light.textTheme.bodyLarge!.color, AppColorsLight.textPrimary);
    });

    test('appBar uses light surface tokens', () {
      expect(light.appBarTheme.backgroundColor, AppColorsLight.bgPrimary);
      expect(light.appBarTheme.foregroundColor, AppColorsLight.textPrimary);
    });

    test('card uses light surface token', () {
      expect(light.cardTheme.color, AppColorsLight.bgSurface);
    });

    test('dialog uses light raised surface', () {
      expect(light.dialogTheme.backgroundColor, AppColorsLight.bgSurfaceRaised);
    });

    test('inputDecoration fill uses light surface', () {
      expect(light.inputDecorationTheme.fillColor, AppColorsLight.bgSurface);
    });

    test('navigationBar uses light surface', () {
      expect(
        light.navigationBarTheme.backgroundColor,
        AppColorsLight.bgSurface,
      );
    });

    test('font is still Geist', () {
      expect(light.textTheme.bodyLarge!.fontFamily, 'Geist');
    });
  });
}
