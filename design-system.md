# Uncommon Path — Design System

> Not a SaaS. A back-of-house tool for a brewery and pizza kitchen that happens
> to run in a browser. It should feel like a clipboard on stainless, not a
> dashboard in a pitch deck.

---

## 1. What this is (and isn't)

**This is:** the visual and interaction vocabulary for the UPB back-of-house
app. Colors, type, spacing, component rules, density modes, motion.

**This isn't:** a marketing brand book, a component library dump, or an
override on shadcn defaults for the sake of it. Every token here exists
because a generic admin template would have been worse.

**House rules:**
- No gradients on white. No ambient glows. No "glassmorphism."
- No rounded-xl-everything. Radius is measured, not the default.
- No neutral gray UI. Our neutrals are **warm**.
- No drop shadows where a 1px border does the same job for less visual cost.
- Type is opinionated. Helvetica / Inter-only is not an option.

---

## 2. Voice

Direct, present tense, kitchen-native. The UI talks like a line cook talks
on a clean day: short, specific, no hedging.

| Don't | Do |
|---|---|
| "Successfully saved!" | "Saved." |
| "Are you sure you want to delete this item?" | "Delete this? Undo is a pain." |
| "Oops! Something went wrong." | "Save failed. Check your connection." |
| "Please enter a valid quantity" | "Qty required." |
| "Dashboard" | "Today" |

Labels are nouns. Actions are verbs. Empty states tell you what to do next,
not what's missing.

---

## 3. Color

Anchored warm. The palette is a working kitchen at two times of day:
carbon-and-ember at night (office / close), linen-and-ember at day (prep /
service).

### 3.1 Tokens

```
/* Surfaces (warm-cool neutrals, never flat gray) */
--upb-carbon:  #15110F;   /* near-black, default night surface */
--upb-ash:     #231D1A;   /* raised surface on carbon */
--upb-iron:    #3A302B;   /* borders, dividers on dark */
--upb-bone:    #E8E1D6;   /* base text on carbon / base surface on day */
--upb-linen:   #F3ECDF;   /* day surface */
--upb-chalk:   #FBF7EE;   /* raised surface on day */
--upb-dust:    #C9BFAE;   /* muted text, inactive labels */

/* Accents (used sparingly, deliberately) */
--upb-ember:   #D24A1A;   /* primary action, focus, the only real accent */
--upb-ember-ink: #2C0A00; /* readable text on ember */
--upb-lichen:  #5E7C3A;   /* success, pass */
--upb-rust:    #9B2B1B;   /* error, out-of-range, corrective-required */
--upb-amber:   #E4A21A;   /* warnings, stale-cost badges */
--upb-slate:   #3D5463;   /* info, rarely used; never for primary actions */

/* Semantic (prefer these in code over raw hex) */
--surface:          var(--upb-linen);     /* day default */
--surface-raised:   var(--upb-chalk);
--surface-sunken:   #EDE6D6;
--ink:              #1A1613;
--ink-muted:        #5A4E44;
--border:           #C9BFAE;
--border-strong:    #8C7F6E;
--focus:            var(--upb-ember);
--accent:           var(--upb-ember);
--accent-ink:       var(--upb-ember-ink);
--success:          var(--upb-lichen);
--danger:           var(--upb-rust);
--warning:          var(--upb-amber);
```

Night mode swaps `--surface` to `--upb-carbon`, `--surface-raised` to
`--upb-ash`, `--ink` to `--upb-bone`, `--border` to `--upb-iron`. The accents
do **not** change.

### 3.2 Rules

- `--accent` is the **only** color used for primary CTAs, focus rings, and
  active-nav indicators. If you're reaching for a second accent, you're
  designing a different feature.
- Status colors (`success/danger/warning`) are for **state**, never for
  decoration. A green border on a passing line check; not a green "Save" button.
- No opacity less than 40% for disabled. `opacity: 0.4` on the ink color,
  not a pale tint of the background.

---

## 4. Typography

Two families, used with intent.

```
--font-display: "Source Serif 4", "GT Sectra", Georgia, serif;   /* rare, heavy moments */
--font-body:    "Inter Tight", "Inter", system-ui, sans-serif;   /* everything */
--font-mono:    "JetBrains Mono", "IBM Plex Mono", ui-monospace; /* numbers, codes, SKUs */
```

- **Display** is for screen titles (Today / Receiving / Line Checks) and
  empty-state headlines. Nowhere else. If it feels marketing-y, it is.
- **Body** is the workhorse. Tight tracking, 500 weight for headings, 400
  for body, 600 only in tables for column headers.
- **Mono** is for anything countable: SKUs, quantities, temperatures, prices.
  Numbers should never reflow just because the proportional font decided a
  "7" was narrower today.

### 4.1 Scale

| Token | Size / line | Use |
|---|---|---|
| `text-xs` | 12 / 16 | meta, timestamps, helper text |
| `text-sm` | 13 / 18 | table rows (office mode) |
| `text-base` | 15 / 22 | body, forms |
| `text-md` | 17 / 24 | table rows (line mode) |
| `text-lg` | 20 / 28 | subtitles, card values |
| `text-xl` | 26 / 32 | section headers |
| `text-display` | 40 / 44 | screen titles (serif) |

Never go below 13px. A cook wiping flour off a screen should not have to
squint. Tabular data uses `font-variant-numeric: tabular-nums`.

---

## 5. Spacing, radius, borders

### 5.1 Spacing scale
```
0   2   4   8   12   16   24   32   48   64
```
No arbitrary values. If you need 20px, you need 16 or 24 and you didn't think
about it yet.

### 5.2 Radius
```
--r-0: 0px;   /* tables, panels, inputs inside a form */
--r-1: 2px;   /* default for cards, most surfaces */
--r-2: 4px;   /* buttons, chips, pills that must feel tappable */
```
`rounded-xl` does not exist. `rounded-full` is reserved for avatars only.

### 5.3 Borders and elevation
- **Default:** 1px solid `--border`. This is how we separate things.
- **Strong:** 1px solid `--border-strong` — used for table headers, the
  edge between a panel and the app chrome.
- **Focus:** 2px solid `--accent`, inset, never accompanied by a glow.
- **Shadow:** one shadow token, used rarely.
  ```
  --shadow-offset: 2px 2px 0 0 var(--ink); /* silkscreen, not cloud */
  ```
  Applied to popovers, menus, and the confirm-destructive modal. Nothing else.

---

## 6. Density modes

The same screen has two layouts. The user picks once per device; the app
remembers.

### 6.1 Line mode (default on iPad)
- Minimum 48px hit target on all primary actions.
- Body text 17px, table rows 17/24.
- Form inputs are 56px tall.
- One-thumb reach preferred: primary CTA bottom-right.
- No hover-only affordances. Anything that reveals on hover also has a
  persistent visible cue.

### 6.2 Office mode (default on desktop ≥ 1200px)
- 32px hit targets, 13px text, denser tables (36px rows).
- Keyboard shortcuts enabled; shortcut key shown in menus (`⌘K`, `N`, `G I`).
- Second column of metadata surfaces (last-received, last-cost, trend)
  without requiring a row expand.

### 6.3 Responsive fallback
No phone "sidebar drawer + hamburger" pattern. The phone view is a
task-focused list: one column, bottom tab bar for the three loops
(Prep / Line / Receiving).

---

## 7. Components (opinions)

### 7.1 Buttons
- **Primary:** filled `--accent`, `--accent-ink` text, 2px radius, 1px
  `--accent-ink` bottom border for weight.
- **Secondary:** transparent, 1px `--border-strong` border, `--ink` text.
- **Ghost:** transparent, `--ink-muted` text, underline on hover/focus.
- **Destructive:** filled `--danger`, white text, 2px radius. Always paired
  with a typed-confirm for irreversible ops (e.g. type the SKU).

Icon-only buttons carry an invisible label via `aria-label` and show a
tooltip after 500ms. No pure-icon CTAs on Line mode.

### 7.2 Inputs
- 1px border, 1px radius, 12px horizontal padding.
- Label above, not floating. Floating labels lose on wet hands.
- Numeric inputs use `--font-mono`, right-aligned.
- Inline unit suffix (`lb`, `qt`) inside the input, `--ink-muted`.

### 7.3 Tables
- No row striping. Striping is what you do when your alignment is weak.
- 1px `--border` row dividers, slightly darker header border.
- Numeric columns right-aligned, `tabular-nums`, monospace for the value.
- Sort affordance is a 10px caret in the column header, `--ink-muted`,
  `--ink` on active.
- Sticky header at all breakpoints. Sticky first column on touch.
- Empty state in the tbody, not a separate card.

### 7.4 Cards & panels
- Radius 2px, 1px `--border`.
- No drop shadow.
- Panel header: `--border-strong` bottom border, `--ink` text, uppercase
  tracking-wide for section labels (12px, 0.08em tracking).

### 7.5 Stat cards (dashboard)
- Label (12px uppercase, `--ink-muted`) above value.
- Value (32px, `--font-mono` if numeric, `--font-display` if a named state
  like "Open" / "Closed").
- Delta below, using `--success`/`--danger` for sign, `--ink-muted` for zero.
- Never a sparkline in the card header; sparklines get their own row.

### 7.6 Nav
- Left sidebar in office mode, 240px wide, flush-left labels, no icons-only
  collapse (we have room).
- Active row: 2px `--accent` left bar, no background fill.
- Section dividers are a label + 1px `--border`, not whitespace.

### 7.7 Toasts, dialogs, alerts
- Toasts: bottom-left, 320px wide, 1px `--border-strong`, no icon, no
  dismiss animation beyond a 120ms fade.
- Dialogs: centered, `--shadow-offset`, no backdrop blur, 60% `--ink`
  backdrop tint. Primary action on the right.
- Destructive dialogs require typed confirmation for irreversible ops.

### 7.8 Badges / chips
- 2px radius, 1px border matching intent color, text in same color.
- No filled badges except for `stale` cost (amber, filled) and `failed`
  line check (rust, filled), because they need to shout.

---

## 8. Iconography

- Line icons, 1.75px stroke, drawn on a 24px grid; 32px and 48px for Line
  mode. Lucide is the base; we diverge where we need kitchen-specific
  glyphs (keg, wood oven, walk-in door).
- Icons are never the only label on a destructive or unusual action.
- No duotone. No filled variants.

---

## 9. Motion

- Duration tokens: `--fast: 120ms`, `--med: 180ms`. No `--slow`.
- Easing: `--ease: cubic-bezier(.2, .7, .2, 1)`. One curve, applied everywhere.
- Never animate layout (height, width) on the critical path; animate
  `opacity` and `transform` only.
- No skeleton loaders longer than 400ms. After that, show a real value
  from cache or a clear "—".

---

## 10. Data visualization

Rare, and low-ceremony when it appears.

- Line charts only for time series (cost over 30 days, pars vs on-hand).
- Single-color (`--accent`) lines. Comparison series use `--ink`.
- No axis grid. Horizontal tick marks at value points only.
- No legend box; label series at the end of the line.
- No donut charts. If it's three categories, it's a bar chart; if it's
  two, it's a ratio in a stat card.

---

## 11. Photography (plating / line check photos)

- Square crop, 1:1, no filters. The kitchen took the photo for a reason.
- 2px `--border` frame, no drop shadow.
- Overlay metadata (timestamp, station) in a `--carbon` 60% strip at the
  bottom, `--bone` text, mono.

---

## 12. Accessibility (non-negotiable)

- Contrast: `--ink` on `--surface` ≥ 7:1. `--ink-muted` on `--surface` ≥ 4.5:1.
- Focus is always visible — 2px `--accent` ring, never removed.
- Touch targets ≥ 48px in Line mode, ≥ 32px in Office mode.
- Color is never the only signal: pass/fail shows icon + color, stale-cost
  shows "stale" text + amber fill.
- Motion respects `prefers-reduced-motion`; when set, transitions collapse
  to 0ms.

---

## 13. Naming

Tailwind + shadcn base is allowed but tokens are the source of truth. When
you reach for `bg-slate-900`, stop and use `bg-[--surface]` or a semantic
class (`bg-surface`, `text-ink`). If a shadcn component imports neutrals,
wrap it and re-theme at the wrapper, not globally.

Component files live in `components/ui/` (primitives) and `components/upb/`
(opinionated compositions). Nothing in `components/ui/` is allowed to know
about business concepts.

---

## 14. What this design system refuses to do

- "Customize" shadcn into a different gray. We have our own neutrals.
- Animate on entry. Every extra frame is a frame the cook is waiting.
- Dark-mode-as-invert. Night is its own palette, not a filter.
- Hide destructive actions in overflow menus. Destructive is always
  visible, always slow, always a typed confirm if irreversible.
- Design for first impression. Design for the 200th shift.
