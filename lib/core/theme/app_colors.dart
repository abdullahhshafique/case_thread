import 'package:flutter/material.dart';

/// Design.md §1 colour tokens — the only place raw hex values may appear.
///
/// Values sampled from the approved UI prototype walkthrough (Sept 2026)
/// and cross-checked against the "Complete Project Understanding" doc:
/// near-black navy canvas + mint accent, functional status colors.
/// Components must reference these tokens (or the MaterialColorScheme built
/// from them), never hardcode a hex value — this is what keeps the Phase 2+
/// light theme (Design.md §10) a value swap rather than a refactor.
abstract final class AppColors {
  // Backgrounds (dark navy layers, calm canvas).
  static const Color bgPrimary = Color(0xFF0A1017); // bg-app
  static const Color bgSurface = Color(0xFF121C28); // bg-card
  static const Color bgSurfaceRaised = Color(0xFF16212E); // bg-panel
  static const Color bgMintTint = Color(0xFF122C2D); // accent-mint-bg pill fill

  // Borders / dividers.
  static const Color borderSubtle = Color(0xFF1E2A38);

  // Text.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A99A9);

  // Accents (mint is the single brand accent).
  static const Color accentPrimary = Color(0xFF4ADE9F);
  static const Color accentPrimaryHover = Color(0xFF4EE3B8);

  // Own chat bubble (discussion).
  static const Color chatBubbleOwn = Color(0xFF1E4C44);

  // States — color flags DATA states, never people, never guilt.
  // Amber marks "needs attention / partial" data states and the
  // AI-pending suggestion badge; always paired with a text label.
  static const Color statePending = Color(
    0xFFE1A66B,
  ); // amber — attention/partial
  static const Color stateSuccess = Color(
    0xFF4EE3B8,
  ); // mint — confirmed/verified
  static const Color stateError = Color(0xFFD5666C); // coral — conflict/warning

  // Semantic status colors (prototype walkthrough §2.3).
  static const Color statusOpen = Color(0xFF6193FF); // blue — open/neutral-info
  static const Color statusGap = Color(
    0xFFB98AE0,
  ); // violet — gaps/investigation
  static const Color statusNeutral = Color(
    0xFF8C99A8,
  ); // slate — closed/insufficient
}
