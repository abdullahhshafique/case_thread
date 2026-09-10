# CaseThread — Design System

**Status:** Draft v1.0
**Last updated:** 2026-09-10
**Design direction:** Calm, high-contrast, trust-oriented — navy/slate base with a single restrained accent. Built for a legal/academic case-management context: this is a tool people trust with sensitive material, not a flashy consumer app.
**Related docs:** [PRD.md](./PRD.md) · [Architecture.md](./Architecture.md) · [Rules.md](./Rules.md)

---

## 1. Colour & Theme

Dark-first design (see §8), with a light theme following the same token structure in Phase 2+.

| Token | Hex | Usage |
|---|---|---|
| `bg/primary` | `#0B1220` | App background, deepest layer |
| `bg/surface` | `#1B2436` | Cards, panels, sidebars |
| `bg/surface-raised` | `#242F45` | Modals, popovers, elevated elements |
| `border/subtle` | `#2E3A52` | Dividers, card borders |
| `text/primary` | `#EDEFF3` | Primary text on dark backgrounds |
| `text/secondary` | `#8B96AB` | Secondary/muted text — intentionally lower contrast |
| `accent/primary` (teal) | `#4FA8A0` | Primary buttons, links, active states, focus rings |
| `accent/primary-hover` | `#63BDB4` | Hover state for teal accent elements |
| `state/pending` (amber) | `#E8B04B` | AI-suggestion / pending-review badges only — never used for standard UI |
| `state/success` | `#5FBF7A` | Success confirmations |
| `state/error` | `#E06767` | Errors, destructive actions |

**Rationale:** navy + slate reads as calm and professional rather than "techy dark mode." Teal is the single accent used for anything actionable (buttons, links, active nav). Amber is reserved *exclusively* for the "this is an AI suggestion, not yet human-approved" state — this keeps it meaningfully distinct rather than just another brand color, reinforcing the human-in-the-loop model from the product itself.

### Accessibility Notes

- **White text on dark backgrounds:** `#EDEFF3` on `#0B1220` ≈ **15:1** — exceeds WCAG AAA.
- **Teal accent on dark background:** `#4FA8A0` on `#0B1220` ≈ **7.2:1** — meets WCAG AAA for normal text, safe for body-sized interactive text, not just large text.
- **Amber (pending state) on dark background:** `#E8B04B` on `#0B1220` ≈ **9.8:1** — meets WCAG AAA; always paired with a text label ("AI suggestion"), never color alone, since it's a meaningful status indicator.
- **Muted secondary text:** `#8B96AB` on `#0B1220` ≈ **6.1:1** — intentionally lower contrast than primary text to establish visual hierarchy, but still comfortably clears WCAG AA (4.5:1) for normal text.
- **Never rely on color alone** for any status (pending/success/error) — always pair with an icon or text label, per Rules.md §8.

---

## 2. Typography

| Role | Font | Notes |
|---|---|---|
| UI / body / headings | **Inter** | Clean, highly legible at small sizes, wide language support, free/open |
| Monospace (audit log entries, code, hashes) | **JetBrains Mono** | Used specifically where exact character distinction matters (file hashes, log entries) |

**Type scale (base 16px):**

| Style | Size | Weight | Usage |
|---|---|---|---|
| Display | 32px | 700 | Landing/marketing headline only |
| H1 | 28px | 700 | Page titles |
| H2 | 22px | 600 | Section headers |
| H3 | 18px | 600 | Card/panel titles |
| Body | 16px | 400 | Default text |
| Body small | 14px | 400 | Secondary text, metadata, timestamps |
| Caption | 12px | 500 | Labels, badges, audit log entries |

- Line height: 1.5 for body text, 1.3 for headings.
- Never use font weight below 400 for body text (thin weights fail at small sizes and reduce accessibility).

---

## 3. Design System Link

*(Placeholder — link to the team's Figma file and/or Storybook instance once created in Phase 1.)*
`Figma: [TBD — to be added when the file exists]`
`Storybook: [TBD — to be added alongside the Flutter component library]`

---

## 4. Spacing & Layout Grid

- **Base spacing unit:** 4px. Scale: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64.
- **Layout grid (web):** 12-column grid, 24px gutters, max content width 1280px, centered with fluid side margins beyond that.
- **Breakpoints:**

| Name | Width |
|---|---|
| Mobile | < 600px |
| Tablet | 600–1024px |
| Desktop | 1024–1440px |
| Wide | > 1440px |

- **Card padding:** 16px (mobile), 24px (tablet+).
- **Section spacing:** 48px between major page sections on desktop, 32px on mobile.

---

## 5. Iconography

- **Icon set:** a single consistent outline-style icon set (e.g., Phosphor or Lucide icons) — no mixing filled and outline styles within the same context.
- **Sizes:** 16px (inline with text/caption), 20px (default UI icons in buttons/nav), 24px (section headers, empty states).
- **Usage rules:** icons always paired with a text label in primary navigation (never icon-only nav for accessibility); icon-only buttons (e.g., a toolbar) require an accessible label via tooltip/`Semantics`.
- **Status icons:** pending (clock/sparkle, amber), success (checkmark, green), error (alert, red) — consistent shape language so status is recognizable even without color.

---

## 6. UI Components Catalogue

| Component | Variants | States |
|---|---|---|
| **Button** | Primary (teal fill), Secondary (outline), Destructive (red), Ghost/text | default, hover, pressed, disabled, loading |
| **Input field** | Text, textarea, select, date picker | default, focused (teal ring), error (red border + message), disabled |
| **Card** | Standard, elevated (raised surface token) | default, hover (for clickable cards), selected |
| **Badge** | Status (pending/success/error), Role badge | — |
| **Modal** | Standard, confirmation (destructive action) | open, closing |
| **Table/list row** | Timeline entry, audit log entry, evidence item | default, hover, selected |
| **Avatar** | User, with role label | default, with pending/invited indicator |
| **Toast/snackbar** | Info, success, error | entering, visible, dismissing |
| **Tabs** | Room sections (Dashboard/Timeline/Vault/Discussion) | active, inactive |

Each component's default/hover/disabled/error states must use only the token palette in §1 — no ad hoc colors introduced at the component level.

---

## 7. Motion & Animations

- **Duration:** micro-interactions (button press, hover) 100–150ms; panel/modal transitions 200–250ms; page transitions 250–300ms. Nothing longer than 300ms for functional UI motion.
- **Easing:** standard ease-out for elements entering, ease-in for elements exiting; avoid bouncy/elastic easing — it undercuts the calm, trust-oriented tone.
- **When to use:** confirm state changes (item added to timeline, AI suggestion appearing — a subtle fade/slide-in, not an attention-grabbing bounce, since it's a "please review" moment, not a celebration), loading states (skeleton screens preferred over spinners for content areas), and role/permission-gated content (fade in once resolved, rather than a layout jump).
- **Avoid:** decorative animation that doesn't communicate a state change; anything that could distract during a review of sensitive case material.

---

## 8. Imagery & Illustration Style

- **Photography:** avoid stock photography of "generic business people" — if imagery is needed (marketing site, empty states), prefer simple geometric illustration over photos.
- **Illustration:** flat, minimal, line-based, using only palette tokens (teal accent, navy/slate base) — consistent with the architecture/workflow diagram style defined in Phases.md §9.
- **Gradients:** used sparingly, only as subtle background texture (e.g., a very subtle navy-to-slate gradient on marketing/landing surfaces) — never on functional UI surfaces where it could reduce text contrast.
- **Empty states:** simple line illustration + concise copy ("No evidence yet — upload your first document to get started") rather than a large decorative graphic.

---

## 9. Voice & Tone (Copy)

- **Personality:** professional, direct, calm — never playful or cute, given the sensitive nature of the content (legal, academic misconduct, medical). Think "a competent colleague," not "a friendly assistant."
- **Error messages:** specific and actionable, never blaming the user. E.g., "Your role — Observer — can't upload evidence in this room" rather than "Permission denied" or "Oops, something went wrong."
- **AI suggestion copy:** always framed as a suggestion requiring review — "AI flagged a possible contradiction — review it" rather than "AI found a contradiction," which overstates certainty.
- **Empty/onboarding states:** encouraging but factual — no exclamation-point-heavy marketing voice inside the working product.

---

## 10. Dark Mode / Theming

- **MVP:** dark theme only (per §1 tokens) — this is the primary/default experience, not a toggle-on mode.
- **Light theme (Phase 2+):** built on the same token *names* with light-appropriate values (e.g., `bg/primary` becomes a near-white, `text/primary` becomes near-black), so components never hardcode a color — only reference tokens.
- **System preference:** once light mode exists, default to matching OS-level preference (`prefers-color-scheme`), with a manual override available in user settings.

---

## 11. Accessibility Design

- **Focus indicators:** every interactive element has a visible focus ring using `accent/primary` at 2px, never removed via `outline: none` without a replacement.
- **Touch target size:** minimum 44x44 logical pixels for any tappable element, per Rules.md §8.
- **Reading order:** DOM/widget tree order matches visual order — no CSS/layout tricks that visually reorder content in a way that breaks screen-reader flow.
- **Form labelling:** every input has a persistent, programmatically associated label (not placeholder-only) — critical given forms here often involve sensitive data entry (evidence metadata, case details) where a user needs to double check what they're filling in.

---

## 12. Responsive & Adaptive Behaviour

- **Mobile:** single-column layouts; primary navigation collapses to a bottom tab bar (Dashboard / Timeline / Vault / Discussion / More); secondary actions move into an overflow menu.
- **Tablet:** two-column layouts where useful (e.g., list + detail pane for evidence vault).
- **Desktop:** full multi-panel layouts (sidebar nav + main content + optional right-hand context panel, e.g., audit log or member list).
- **Content reflow, not just hiding:** on narrow viewports, tables (e.g., audit log) reflow into stacked card-style rows rather than requiring horizontal scroll.

---

## 13. Brand Assets

*(Placeholder — to be produced alongside Phase 1 UI build.)*
- **Logo:** wordmark "CaseThread" in Inter Semi-Bold, teal accent on navy, plus a simple mark (e.g., an abstract linked-thread/node motif reflecting the entity-relationship concept) — final logo file paths TBD, store under `/docs/assets/brand/`.
- **Clearspace:** minimum clearspace around the logo equal to the height of the wordmark's cap-height.
- **Favicon:** simplified single-color version of the mark, navy background, teal glyph, exported at standard favicon sizes (16/32/48px + SVG).
