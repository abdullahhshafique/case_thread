# CaseThread — Design System

**Status:** Draft v2.1 (adds §16 — v3 console addendum)
**Last updated:** 2026-09-19
**Design direction:** Calm, investigation-grade, dark navy canvas with a single restrained mint accent. Colors are functional: mint = confirmed/healthy, amber = needs attention/partial, coral = conflict, slate = neutral/unknown. Nothing implies guilt — colors flag *data states*, not people.
**Source of truth:** sampled from the approved UI prototype walkthrough (Sept 2026) and cross-referenced with the "Complete Project Understanding" document.
**Related docs:** [PRD.md](./PRD.md) · [Architecture.md](./Architecture.md) · [Rules.md](./Rules.md)

> Visual idea: **Scattered Info → Connections → Analysis → Clear Picture.**

---

## 1. Colour & Theme

Dark-first design (see §10). All values live in `lib/core/theme/app_colors.dart` — components reference tokens, never raw hex.

### 1.1 Surface / background layers

| Token | Hex | Usage |
|---|---|---|
| `bg/primary` (bg-app) | `#0A1017` | App background, deepest layer, icon rail |
| `bg/surface` (bg-card) | `#121C28` | Cards, stat tiles, evidence/task rows |
| `bg/surface-raised` (bg-panel) | `#16212E` | Panels, modals, popovers, snackbars |
| `bg/mint-tint` | `#122C2D` | Pill fill behind mint text (status badges, active tiles) |
| `border/subtle` | `#1E2A38` | Hairline borders separating cards/rows |

### 1.2 Brand / accent

| Token | Hex | Usage |
|---|---|---|
| `accent/primary` (mint) | `#4ADE9F` | Primary buttons, links, active tab label + underline, progress fill, focus rings |
| `accent/primary-hover` | `#4EE3B8` | Hover/positive status dot |
| `chat/bubble-own` | `#1E4C44` | Solid fill for the current user's own chat bubble |

### 1.3 Status colors (functional, not decorative)

| Status | Token | Hex | Where used |
|---|---|---|---|
| 🟢 Confirmed / Active | `state/success` | `#4EE3B8` | Under-Investigation status, verified alibi progress, Fact tags |
| 🟠 Attention / Partial | `state/pending` | `#E1A66B` | Review status, Partially-Verified alibi, in-progress gaps, **AI-pending suggestion badge** |
| 🔴 Conflict / Warning | `state/error` | `#D5666C` | Contradiction icons, Conflict alibi badge, high-severity counts |
| 🔵 Open / Neutral-info | `status/open` | `#6193FF` | Open case status, Finding tags |
| 🟣 Gaps / Investigation | `status/gap` | `#B98AE0` | Gaps stat number, gap highlights |
| ⚪ Closed / Insufficient | `status/neutral` | `#8C99A8` | Closed status, Insufficient-Data alibi, muted/disabled states |

**Rationale:** near-black navy keeps the chrome quiet so colored status cues (badges, chips, chart bars) draw the eye. Mint is the single brand accent for anything actionable. Amber originally reserved exclusively for AI-pending; v2 extends it to "needs attention / partial" data states (Review status, partially-verified alibis) — in every use it is paired with a text label, never color alone.

**Amber + AI rule (v2):** amber flags data that needs human attention — which is exactly what a pending AI suggestion is. The AI badge keeps its distinctive pairing (amber border + "AI suggestion" label + hourglass icon) so it stays recognizable.

### 1.4 Text

| Token | Hex | Usage |
|---|---|---|
| `text/primary` | `#FFFFFF` | Headings, case titles, message body |
| `text/secondary` | `#8A99A9` | Timestamps, sub-labels, metadata, counts |

### 1.5 Avatar chip colors

Soft-tinted circular chips (dark fill + saturated initials), rotating through a small palette for consistent teammate identity:

| Chip fill | Letter color |
|---|---|
| dark green `#28433A` | mint `#3E8F71` |
| dark teal `#21313A` | soft blue-teal `#93BDD6` |
| dark violet `#302547` | lavender `#9E88C0` |
| dark slate `#233848` | muted steel-blue `#829FB7` |

### Accessibility Notes

- **White on bg-app:** `#FFFFFF` on `#0A1017` ≈ **18:1** — exceeds WCAG AAA.
- **Mint accent on bg-app:** `#4ADE9F` on `#0A1017` ≈ **10:1** — exceeds WCAG AAA, safe for body-sized interactive text.
- **Secondary text:** `#8A99A9` on `#0A1017` ≈ **6:1** — comfortably clears WCAG AA while establishing hierarchy.
- **Status colors:** always paired with an icon or text label (never color alone) — mint/amber/coral/slate are data-state flags, per Rules.md §8 and the no-guilt-copy rule (Design.md §9).

---

## 2. Typography

| Role | Font | Notes |
|---|---|---|
| UI / body / headings | **Inter** | Clean geometric/humanist sans (SF Pro / Segoe UI class). No serif or decorative fonts anywhere |
| Monospace (audit log entries, code, hashes) | **JetBrains Mono** | Where exact character distinction matters (file hashes, log entries) |

**Weight scale:** Bold/Semibold for screen titles ("Cases", "Riverside Robbery"), stat numbers, active tab labels, sender names, card titles. Regular/Medium for body, list secondary lines, chat messages.

**Type scale (base 16px):**

| Style | Size | Weight | Usage |
|---|---|---|---|
| Display | 32px | 700 | Landing headline only |
| H1 | 28px | 700 | Page titles |
| H2 | 22px | 600 | Section headers |
| H3 | 18px | 600 | Card/panel titles |
| Body | 16px | 400 | Default text |
| Body small | 14px | 400 | Secondary text, metadata, timestamps |
| Caption | 12px | 500 | Labels, badges, audit entries |

- Stat-tile numbers are noticeably larger and bolder than their labels, and **color-coded by meaning** (white neutral, coral conflicts, violet gaps).
- Line height: 1.5 body, 1.3 headings. Never below weight 400 for body text.

---

## 3. Design System Link

*(Placeholder — link to the team's Figma file and/or Storybook instance once created.)*
`Figma: [TBD]` · `Storybook: [TBD]`

---

## 4. Spacing, Layout & Shape

- **Base spacing unit:** 4px. Scale: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64.
- **Breakpoints:** Mobile < 600px · Tablet 600–1024 · Desktop 1024–1440 · Wide > 1440.
- **Card padding:** 16px (mobile), 24px (tablet+). Generous internal padding (~16–20px).
- **Corner radius: large everywhere — nothing is sharp-cornered.** Cards, pills, chat bubbles, modals: 10–14px (`radius/card` = 12px, `radius/pill` = 999px). Buttons and inputs use 12px.
- **Depth via contrast, not shadows:** cards separate by background contrast and subtle 1px `border/subtle` borders — flat and calm, no heavy drop shadows.
- **Grouped panel cards:** related items (e.g. "Needs your attention") live in one card with thin dividers between rows.

### Global shell patterns

- **Mobile:** single column, bottom tab bar; Quick Actions as a horizontal chip row.
- **Desktop (3-pane):** icon rail (~52px, active item gets a mint-tinted rounded-square tile) · list panel (~300px with title, search, filter chips, "Waiting on you" banner) · main panel (Case Room).
- **Case Room header:** avatar + case name + `#ID` + status pill + member count, horizontal tab bar underneath (active = bold mint text + mint underline).

---

## 5. Iconography

- **Style:** simple line/stroke icons, consistent weight, rounded joins — matches the rounded-corner language.
- **Sizes:** 16px inline, 20px default UI, 24px section headers/empty states.
- **Color logic:** glyph color matches semantics (coral triangle = contradiction, amber scales = alibi, slate question-mark = gap, mint = positive/brand); icon *background tile* is a low-opacity tint of the same hue.
- **Set:** share/graph nodes (product mark), briefcase (cases), clipboard-check (tasks, with badge), activity/pulse (audit), search, bell (with red count badge), people, sparkle (AI), triangle-alert, scales-of-justice, question-circle, chat-bubble, video-camera, document, link/chain, paperclip, lock, chevron-right.
- Icon-only buttons always carry an accessible label via tooltip/`Semantics`.

---

## 6. UI Components Catalogue

| Component | Variants | States |
|---|---|---|
| **Button** | Primary (mint fill), Secondary (outline), Destructive (coral), Ghost/text | default, hover, pressed, disabled, loading |
| **Input field** | Text, textarea, select, date picker | default, focused (mint ring), error, disabled |
| **Card** | Standard, elevated (raised token) | default, hover, selected (mint left-edge bar + background lift) |
| **Status badge/pill** | ● Under Investigation (mint) · ● Review (amber) · ● Open (blue) · ● Closed (slate) — leading dot + colored label on low-opacity tint | — |
| **Count chip** | Icon + number sharing one status color (coral warnings, amber gaps, gray docs) | — |
| **Case list row** | Avatar · name + relative time · last-activity preview · status pill + `#ID` + count chips; selected row gets mint left-edge bar | default, selected |
| **"Waiting on you" banner** | Mint lightning tile + bold title + one-line rollup + chevron | — |
| **Dashboard stat tile** | Large bold color-coded number over small gray label | — |
| **Progress bar** | 4–6px rounded, mint fill over darker track + % caption | — |
| **"Needs your attention" list** | Colored icon tile + bold title + gray subtitle (source ID · priority) + chevron | — |
| **Activity feed row** | Icon + event line + detail + relative time | — |
| **Mini bar chart** | Vertical mint bars per evidence type, gray labels — glanceable, not dense | — |
| **Quick actions grid** | 2×2 rounded utility buttons (Add evidence/event/person/statement) — neutral card bg, never accent-colored | — |
| **Discussion** | Teammate: avatar chip + name (mint) + role (gray) + slate bubble; linked-evidence chip nested in bubble; own: right-aligned mint-tinted bubble; system dividers: centered gray pill text; composer: bottom bar with attach menu + circular mint send | — |
| **Timeline entry** | Line-and-dot node + date/time + card with type tag (Record/Claim/Finding/Unknown) + linked-source chip; filter chips above (All/Records/Claims/Unknown) | — |
| **Evidence card** | Icon tile + title/reference code + metadata line + Record tag + linked-entity chips | — |
| **Analysis tabs** | Segmented control (Alibis/Contradictions/Gaps), filled active segment; persistent non-accusatory caption card (§9) | — |
| **Contradiction modal** | Icon + title + ID/priority subtitle + × close; Side A / Side B rows; metadata table (Window/Place/Why flagged); clarifying callout; actions: **Dismiss** (ghost) · **Create task** (outline) · **Resolve** (solid mint) | — |
| **Tasks** | Checklist card: mint circular check when done (label struck + dimmed), source tag (Gap G-01 / Contradiction C-02), assignee avatar, due label; "Create task" mint text-link | — |
| **Notifications panel** | Bell-anchored modal: "N new" + Mark-all-read link, grouped rows (color/type-coded icon tile + headline + detail + time), footer tip bar | — |
| **Empty state** | Centered: large outline icon + bold short title + gray description | — |
| **Avatar** | User, with role label; tinted identity chips (§1.5) | default, pending/invited |
| **Toast/snackbar** | Info, success, error | entering, visible, dismissing |
| **Tabs** | Room sections | active (bold + mint underline), inactive |

Every component's states use only the §1 token palette — no ad hoc colors at the component level.

---

## 7. Motion & Animations

- **Duration:** micro-interactions 100–150ms; panel/modal transitions 200–250ms; page transitions 250–300ms. Nothing over 300ms.
- **Easing:** ease-out entering, ease-in exiting; no bouncy/elastic easing — calm, trust-oriented tone.
- **When:** confirm state changes (AI suggestion appearing = subtle fade/slide "please review", not a celebration), loading (skeletons preferred), permission-gated content (fade in once resolved).
- **Avoid:** decorative animation; anything distracting during review of sensitive material.

---

## 8. Imagery & Illustration Style

- **Photography:** avoid generic stock; prefer geometric illustration.
- **Illustration:** flat, line-based, palette tokens only.
- **Gradients:** sparingly, subtle background texture only — never on functional UI surfaces.
- **Empty states:** line illustration + concise factual copy.

---

## 9. Voice & Tone (Copy)

- **Personality:** professional, direct, calm — "a competent colleague," not "a friendly assistant."
- **Error messages:** specific and actionable, never blaming ("Your role — Observer — can't upload evidence in this room").
- **AI suggestion copy:** framed as a suggestion requiring review, never overstating certainty.
- **Non-accusatory framing (from the prototype, doc §5.14):** analysis screens carry a persistent guiding caption, e.g. *"A conflict is a difference between a claim and a record. It is not a conclusion about guilt."* Action verbs are safe by default — **Dismiss / Create task / Resolve** — never "Confirm guilt".
- **Empty/onboarding states:** encouraging but factual, no exclamation-heavy marketing voice.

---

## 10. Dark Mode / Theming

- **MVP:** dark theme only (per §1 tokens) — the primary/default experience.
- **Light theme (Phase 2+):** same token *names*, light-appropriate values, so components never hardcode colors.
- **System preference:** once light mode exists, match OS preference with a manual override.

---

## 11. Accessibility Design

- **Focus indicators:** every interactive element has a visible 2px mint focus ring.
- **Touch targets:** minimum 44×44 logical pixels (Rules.md §8).
- **Reading order:** widget-tree order matches visual order.
- **Form labelling:** every input has a persistent programmatic label — critical for sensitive data entry.
- **Status presentation:** color + icon + text label together (never color alone), and analysis copy never implies guilt from a data state.

---

## 12. Responsive & Adaptive Behaviour

- **Mobile:** single column; bottom tab bar; Quick Actions as a horizontal chip strip.
- **Tablet:** two-column where useful (list + detail).
- **Desktop:** 3-pane shell (icon rail + list panel + main panel); audit log / members as right-hand context panels.
- **Content reflow:** tables reflow into stacked card rows on narrow viewports.

---

## 13. Brand Assets

*(Placeholder — to be produced alongside the UI build.)*
- **Logo:** wordmark "CaseThread" in Inter Semi-Bold, mint accent on navy, plus an abstract linked-thread/node mark (reflecting the entity-relationship concept).
- **Clearspace:** minimum equal to the wordmark's cap-height.
- **Favicon:** single-color mark, navy background, mint glyph (16/32/48px + SVG).

---

## 14. Token Quick Reference (CSS-style)

```css
/* Backgrounds */
--bg-app: #0A1017;
--bg-panel: #16212E;
--bg-card: #121C28;
--bg-mint-tint: #122C2D;
--border-subtle: #1E2A38;

/* Brand */
--accent-mint: #4ADE9F;
--accent-mint-hover: #4EE3B8;
--chat-bubble-own: #1E4C44;

/* Status */
--status-confirmed: #4EE3B8;  /* mint  — Under Investigation / Verified / Fact */
--status-attention: #E1A66B;  /* amber — Review / Partially Verified / AI pending */
--status-conflict:  #D5666C;  /* coral — Conflict / Contradiction */
--status-open:      #6193FF;  /* blue  — Open / Finding */
--status-gap:       #B98AE0;  /* violet — Gaps */
--status-neutral:   #8C99A8;  /* slate — Closed / Insufficient / Unknown */

/* Text */
--text-primary: #FFFFFF;
--text-secondary: #8A99A9;

/* Shape */
--radius-card: 12px;
--radius-pill: 999px;
```

---

## 15. How this maps to the product spec

- **Fact / Claim / Finding / Unknown** → distinct tag styles in Timeline & Evidence (Record = mint, Claim = amber, Finding = blue, Unknown = slate) + filter chips.
- **"Never a guilt conclusion"** → deliberately neutral action verbs (Dismiss / Create task / Resolve) and in-UI disclaimers ("It is not a conclusion about guilt").
- **Gaps as actionable** → every gap row and contradiction becomes a Task in one click; the guiding caption says so.
- **Mobile-first, card-based** → every module is the same stackable card-row pattern, collapsing naturally to one mobile column.
- **Dark navy + mint theme** → confirmed by the instructor; implemented as the default theme via `app_colors.dart` + `app_theme.dart`.

*v2 note: exact hex values are best-effort samples from compressed prototype footage (±5–10 units). If a Figma file or official token file appears, it becomes the source of truth.*

---

## 16. v3 Console Addendum (2026-09-19)

Phase 6 rebuilt the Flutter shell to the approved v3 HTML console (`casethread-v3.html`). This addendum records where v3 supersedes or extends §1–§14. Everything here is implemented in `app_colors.dart` / `app_text_theme.dart` / `app_theme.dart` / `lib/shell/ambient_atmosphere.dart`.

**16.1 Typography — Geist replaces Inter as the UI face.** The theme's base family is now **Geist** (weights 400–900 bundled) and the mono face is **Geist Mono** (replacing JetBrains Mono in `AppTextTheme.mono` and all tabular/monospace UI). Inter and JetBrains Mono remain bundled as fallbacks. §2's size/weight scale is unchanged.

**16.2 Brand gradient.** A three-stop brand gradient is the chrome accent for active-tab indicators, meters, selected-case rails, and the logo mark: teal `#08CBD8` → blue `#3D71FF` → violet `#A54EFF` (`AppColors.brandGradient`). This coexists with the single mint accent of §1.2: mint still owns *case-data* semantics (confirmed/verified/healthy); the gradient is decorative chrome only, never a data-state color.

**16.3 Console surfaces & text.** The console shell uses a darker surface set than §1.1: `consoleBg #05060A`, `consoleSidebar #07080C`, `consolePanel #0B0D14`, `consolePanel2 #10131D`, with `consoleText #F7F8FC`, `consoleTextSecondary #B7C6DC`, `consoleMuted #9AA2B6`, and `consoleBorder` (white @ 9%).

**16.4 Status pairs.** v3 §3.6 adds tinted status *pairs* (foreground + background + border always used together): `v3Ok #6EE7B7`, `v3Warn #FCD34D`, `v3Err #FDA4AF`, `v3Info #A5B4FC`, `v3Violet #C4B5FD`, `v3Cyan #67E8F9`. These map onto the §1.3 semantics (ok→success, warn→attention, err→conflict) — the no-guilt labeling rules of §9 apply unchanged.

**16.5 Ambient atmosphere.** One shared decorative layer behind the shell: 54px shell grid, slow conic aurora, two breathing glow orbs. Purely decorative (pointer-transparent), and fully disabled under `prefers-reduced-motion` — consistent with §7's motion restraint.

**16.6 What did NOT change:** all §1.3 data-state colors, §9 voice/tone (non-accusatory copy), §11 accessibility rules, and the component semantics of §6. The v3 work is chrome + typography; case-data meaning is still carried by the §1 tokens.
