import 'package:flutter/material.dart';

/// Design.md §1 colour tokens — the only place raw hex values may appear.
///
/// Components must reference these tokens (or the MaterialColorScheme built
/// from them), never hardcode a hex value — this is what keeps the Phase 2+
/// light theme (Design.md §10) a value swap rather than a refactor.
abstract final class AppColors {
  // Backgrounds.
  static const Color bgPrimary = Color(0xFF0B1220);
  static const Color bgSurface = Color(0xFF1B2436);
  static const Color bgSurfaceRaised = Color(0xFF242F45);

  // Borders / dividers.
  static const Color borderSubtle = Color(0xFF2E3A52);

  // Text.
  static const Color textPrimary = Color(0xFFEDEFF3);
  static const Color textSecondary = Color(0xFF8B96AB);

  // Accents.
  static const Color accentPrimary = Color(0xFF4FA8A0);
  static const Color accentPrimaryHover = Color(0xFF63BDB4);

  // States. Amber is reserved EXCLUSIVELY for pending AI suggestions
  // (Design.md §1) — never reuse it for generic "pending" UI.
  static const Color statePending = Color(0xFFE8B04B);
  static const Color stateSuccess = Color(0xFF5FBF7A);
  static const Color stateError = Color(0xFFE06767);
}
