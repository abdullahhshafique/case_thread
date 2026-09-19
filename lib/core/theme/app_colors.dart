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

  // ── v3 console tokens (casethread-v3.html §0) ───────────────────────
  // Brand gradient: teal → blue → violet (used for active-tab edge bars,
  // meters, selected-case rails, logo mark).
  static const Color brandTeal = Color(0xFF08CBD8);
  static const Color brandBlue = Color(0xFF3D71FF);
  static const Color brandViolet = Color(0xFFA54EFF);
  static const Gradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandTeal, brandBlue, brandViolet],
  );

  // Console semantic surfaces (v3 §3.2 — darker than Design.md navy).
  static const Color consoleBg = Color(0xFF05060A);
  static const Color consoleSidebar = Color(0xFF07080C);
  static const Color consolePanel = Color(0xFF0B0D14);
  static const Color consolePanel2 = Color(0xFF10131D);
  static const Color consoleText = Color(0xFFF7F8FC);
  static const Color consoleTextSecondary = Color(0xFFB7C6DC);
  static const Color consoleMuted = Color(0xFF9AA2B6);
  static const Color consoleBorder = Color(0x17FFFFFF); // rgba(255,255,255,.09)

  // v3 §3.6 status pairs — foreground + tinted background, always used
  // together (label paired with color, never color alone).
  static const Color v3Ok = Color(0xFF6EE7B7);
  static const Color v3Warn = Color(0xFFFCD34D);
  static const Color v3Err = Color(0xFFFDA4AF);
  static const Color v3Info = Color(0xFFA5B4FC);
  static const Color v3Violet = Color(0xFFC4B5FD);
  static const Color v3Cyan = Color(0xFF67E8F9);

  static Color v3StatusBg(Color c) => c.withValues(alpha: 0.10);
  static Color v3StatusBorder(Color c) => c.withValues(alpha: 0.20);
}
