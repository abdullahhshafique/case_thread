
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/app.dart';
import 'package:case_thread/core/theme/app_theme.dart';
import 'package:case_thread/core/theme/theme_mode_provider.dart';

/// Test-only notifier that returns a fixed initial theme mode,
/// bypassing SharedPreferences so tests don't need async setup.
class _TestThemeModeNotifier extends ThemeModeNotifier {
  _TestThemeModeNotifier(this.initial);

  final ThemeMode initial;

  static ThemeModeNotifier withInitial(ThemeMode initial) =>
      _TestThemeModeNotifier(initial);

  @override
  ThemeMode build() => initial;
}

/// Phase 1 PRD: light/dark theme surface colours via buildAppTheme().
void main() {
  group('Theme surface colours (Phase 1)', () {
    test('light theme scaffold uses bgPrimary #F4F6FA', () {
      final theme = buildAppTheme(brightness: Brightness.light);
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFFF4F6FA)));
    });

    test('dark theme scaffold uses bgPrimary #05060A', () {
      final theme = buildAppTheme(brightness: Brightness.dark);
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFF05060A)));
    });

    testWidgets('light theme override applies light scaffold color', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeModeProvider.overrideWith(
              () => _TestThemeModeNotifier.withInitial(ThemeMode.light),
            ),
          ],
          child: const CaseThreadApp(),
        ),
      );
      await tester.pump();

      final bg = tester
          .widget<MaterialApp>(find.byType(MaterialApp).first)
          .theme!
          .scaffoldBackgroundColor;
      expect(bg, equals(const Color(0xFFF4F6FA)));
    });
  });
}
