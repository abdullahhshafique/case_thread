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
  // Backgrounds — canonical values are the v3 console surfaces
  // (Design.md §16.3); token NAMES are unchanged so no component moves.
  static const Color bgPrimary = Color(0xFF05060A); // bg-app = consoleBg
  static const Color bgSurface = Color(0xFF0B0D14); // bg-card = consolePanel
  static const Color bgSurfaceRaised = Color(0xFF10131D); // bg-panel
  static const Color bgMintTint = Color(0xFF122C2D); // accent-mint-bg pill fill

  // Borders / dividers — white @ 9% (v3 §3.2 consoleBorder).
  static const Color borderSubtle = Color(0x17FFFFFF);

  // Text.
  static const Color textPrimary = Color(0xFFF7F8FC);
  static const Color textSecondary = Color(0xFF9AA2B6);

  // Accents — v3 brand blue for actions/focus/links (the teal→blue→violet
  // brandGradient is separate decorative chrome). Mint remains the
  // confirmed/verified case-data color (stateSuccess).
  static const Color accentPrimary = Color(0xFF3D71FF);
  static const Color accentPrimaryHover = Color(0xFF6B8BFF);

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



  // ── Extended tokens (2026-09-25 sweep): every raw hex that lived in
  // feature files now has a named home. Values unchanged — rename-only.
  static const Color v3Indigo = Color(0xFF6366F1);
  static const Color v3DeepViolet = Color(0xFF7C3AED);
  static const Color accentSky = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentPink = Color(0xFFFF65CE);
  static const Color accentRose = Color(0xFFFB7185);
  static const Color accentPeriwinkle = Color(0xFF816CFF);
  static const Color skyGlow = Color(0xFF4FE0FF);
  static const Color mintDeep = Color(0xFF5FBF7A);
  static const Color mintInk = Color(0xFF3E8F71);
  static const Color mintSurface = Color(0xFF28433A);
  static const Color heroBlue = Color(0xFF2563EB);
  static const Color graphEdge = Color(0x4D8180F8);
  static const Color v3IndigoTint = Color(0x1A6366F1);
  static const Color overlayPanel = Color(0xE60B0D14);
  static const Color overlayPanelSolid = Color(0xF20B0D14);
  static const Color borderStrong = Color(0x26FFFFFF);
  static const Color nodeRing = Color(0xFF0A0D16);
  static const Color veilNavy = Color(0xFF0E0E1B);

  static Color v3StatusBg(Color c) => c.withValues(alpha: 0.10);
  static Color v3StatusBorder(Color c) => c.withValues(alpha: 0.20);
}

// ── Light theme palette (PRD §Phase 1) ───────────────────────────
// Same token names as AppColors — components swap the class, no
// refactor required. All values verified against the approved light
// prototype walkthrough.
abstract final class AppColorsLight {
  static const Color bgPrimary = Color(0xFFF4F6FA);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSurfaceRaised = Color(0xFFF0F2F7);
  static const Color bgMintTint = Color(0xFFDDF2F4);

  static const Color borderSubtle = Color(0xFFDDE3EC);

  static const Color textPrimary = Color(0xFF1B2A4A);
  static const Color textSecondary = Color(0xFF5A6B8A);

  // Darkened ~15% for readability on light surfaces (WCAG AA).
  static const Color accentPrimary = Color(0xFF2E5FCC);
  static const Color accentPrimaryHover = Color(0xFF1E48BF);

  static const Color chatBubbleOwn = Color(0xFFDDF2F4);

  static const Color statePending = Color(0xFFB97810);
  static const Color stateSuccess = Color(0xFF1E8A5C);
  static const Color stateError = Color(0xFFB93B42);

  static const Color statusOpen = Color(0xFF2E5FCC);
  static const Color statusGap = Color(0xFF6D44B8);
  static const Color statusNeutral = Color(0xFF5A6B8A);

  // Brand tokens — darkened for light surfaces.
  static const Color brandTeal = Color(0xFF0A9EA8);
  static const Color brandBlue = Color(0xFF2E5FCC);
  static const Color brandViolet = Color(0xFF8438CC);
  static const Gradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandTeal, brandBlue, brandViolet],
  );

  // Console tokens — light variants (v3 §3.2 light).
  static const Color consoleBg = Color(0xFFF4F6FA);
  static const Color consoleSidebar = Color(0xFFEFF1F7);
  static const Color consolePanel = Color(0xFFFFFFFF);
  static const Color consolePanel2 = Color(0xFFF0F2F7);
  static const Color consoleText = Color(0xFF1B2A4A);
  static const Color consoleTextSecondary = Color(0xFF4A5B7A);
  static const Color consoleMuted = Color(0xFF7A8BA8);
  static const Color consoleBorder = Color(0x1A1B2A4A);

  static const Color v3Ok = Color(0xFF1E8A5C);
  static const Color v3Warn = Color(0xFFC07800);
  static const Color v3Err = Color(0xFFB93B42);
  static const Color v3Info = Color(0xFF2E5FCC);
  static const Color v3Violet = Color(0xFF7C3FBF);
  static const Color v3Cyan = Color(0xFF0E8FA8);



  // ── Extended tokens (light counterparts of the 2026-09-25 sweep).
  static const Color v3Indigo = Color(0xFF4F46E5);
  static const Color v3DeepViolet = Color(0xFF6D28D9);
  static const Color accentSky = Color(0xFF1D4ED8);
  static const Color accentCyan = Color(0xFF0E7490);
  static const Color accentPink = Color(0xFFC026D3);
  static const Color accentRose = Color(0xFFBE123C);
  static const Color accentPeriwinkle = Color(0xFF6D28D9);
  static const Color skyGlow = Color(0xFF0891B2);
  static const Color mintDeep = Color(0xFF15803D);
  static const Color mintInk = Color(0xFF166534);
  static const Color mintSurface = Color(0xFFDCF2E8);
  static const Color heroBlue = Color(0xFF1D4ED8);
  static const Color graphEdge = Color(0x334F46E5);
  static const Color v3IndigoTint = Color(0x1A4F46E5);
  static const Color overlayPanel = Color(0xE6FFFFFF);
  static const Color overlayPanelSolid = Color(0xF2FFFFFF);
  static const Color borderStrong = Color(0x261B2A4A);
  static const Color nodeRing = Color(0xFFFFFFFF);
  static const Color veilNavy = Color(0xFFE8ECF4);

  static Color v3StatusBg(Color c) => c.withValues(alpha: 0.10);
  static Color v3StatusBorder(Color c) => c.withValues(alpha: 0.20);
}
