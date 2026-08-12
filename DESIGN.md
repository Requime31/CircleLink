# CircleLink — DESIGN.md

> **Sunset Parchment** — soft-native UI for a community messenger.  
> Warm parchment surfaces, Sunset Clay accent, calm hierarchy.  
> Adapted for **SwiftUI / iOS** (SF Pro), not web Inter.

Use this file as the single source of truth for visual decisions.  
Before any UI work: read this file and follow it.

Source brief: `stitch_circlelink_visual_redesign_brief` (Stitch export).

---

## 0. Design Rules (canonical)

These override local screen habits when in doubt. Intentional exceptions are **not bugs** — do not “fix” them into squircles.

| Rule | Spec |
|------|------|
| **Default avatars** | **Squircle** (`radiusMd` / continuous) — Profile, Connect, Communities |
| **Chats avatars** | **Circle** — intentional exception for Chat list / thread / chat info |
| **Connect action row** | Pass / Say Hi / Back = **circle** buttons — intentional; do **not** replace with squircle |
| **Connect Discover hero** | Show **name + age only** on the card; **bio only** in the About section |
| **Default CTA** | Soft: `accentSoft` + `ink` — or secondary hairline |
| **Solid clay CTA** | **Rare** high-emphasis only (FAB, Say Hi, unread accents) — not the default button |
| **Horizontal inset** | `screenHorizontal` = **20** on every screen edge padding |
| **Shadows** | **Hairline first**; elevated / floating shadow is **rare** (Connect hero deck, FAB) |

---

## 1. Visual Theme & Atmosphere

| Trait | Direction |
|-------|-----------|
| Mood | Soft-native, calm, interpersonal warmth |
| Density | Airy whitespace; not dense dashboards |
| Surfaces | Parchment canvas + white cards + hairline edges |
| Accent | **Sunset Clay** — used sparingly to guide focus |
| Depth | Tonal layering + hairlines; shadows only for floating actions |
| Motion | Soft springs / slight dim on press — never flashy |
| Mode | Light-first (no dark-first UI in MVP) |

**Brand test:** screens should feel like CircleLink without the logo — parchment canvas + clay accent + soft squircles (circles only where §0 allows).

---

## 2. Color Palette

Map from Stitch “Sunset Parchment” → CircleLink tokens.

### Core surfaces

| Token | Hex | Role |
|-------|-----|------|
| `canvas` | `#FCF9F8` | Screen background (parchment) |
| `surface` | `#FFFFFF` | Cards, sheets, inputs (`surface-container-lowest`) |
| `surfaceSoft` | `#F6F3F2` | Secondary groups, muted rows (`surface-container-low`) |
| `hairline` | `#E8E4DF` | Dividers, card borders (structural) |
| `hairlineStrong` | `#DCC1B9` | Stronger borders (`outline-variant`) |

### Ink (text)

| Token | Hex | Use |
|-------|-----|-----|
| `ink` | `#1C1B1B` | Primary text (`on-surface`) |
| `inkSecondary` | `#55423D` | Secondary labels (`on-surface-variant`) |
| `inkMuted` | `#88726C` | Captions, placeholders, meta (`outline`) |
| `inkDisabled` | `#B8B2A8` | Disabled text |

### Primary (Sunset Clay)

| Token | Hex | Use |
|-------|-----|-----|
| `primary` | `#E67E5F` | Brand accent, selected chips text, FAB, active accents (`terracotta` / `primary-container`) |
| `primaryPressed` | `#9B442A` | Pressed / deep clay (`primary` in Material tokens) |
| `accentSoft` | `#F8E6E0` | **Default soft CTA** fill (quieter peach; less fatigue) |
| `primarySoft` | `#FFDBD1` | Selected chips / stronger soft highlight (`primary-fixed`) |
| `primaryStrong` | `#9B442A` | High-emphasis fill when white label is needed |
| `onPrimary` | `#1C1B1B` | Label on `accentSoft` / `primarySoft` / soft CTAs |
| `onPrimaryStrong` | `#FFFFFF` | Label on solid clay / deep fill |

### Soft tints

Use lightly — never as full-screen backgrounds.

| Token | Hex | Use |
|-------|-----|-----|
| `tintPeach` | `#FFDBD1` | Soft highlight (= `primarySoft`) |
| `tintCream` | `#F6F3F2` | Empty / calm blocks |
| `tintMint` | `#E4F3EC` | Success-adjacent soft state |
| `tintRose` | `#FFDAD6` | Soft warning / attention (`error-container`) |

### Semantic

| Token | Hex | Use |
|-------|-----|-----|
| `success` | `#3D9B6E` | Connected, sent, confirmed (desaturated) |
| `warning` | `#D4A017` | Caution |
| `error` | `#BA1A1A` | Errors, destructive |
| `errorSoft` | `#FFDAD6` | Error background |

### Rules

- Clay is for **actions and selection**, not decoration everywhere.
- Default primary CTA = **low-impact**: `accentSoft` + `ink` (or secondary hairline).
- Solid `primary` / `primaryStrong` = **rare** high-emphasis only (FAB, Say Hi, unread accents).
- Prefer hairline borders over shadows.
- Never use purple as brand accent.
- Never use neon / glow accents.

---

## 3. Typography (SwiftUI)

Use **SF Pro** (system). Do **not** embed Inter (web-only in the brief).

| Style | Size | Weight | Use |
|-------|------|--------|-----|
| `display` | 34 | Bold | Rare marketing-style titles |
| `largeTitle` | 28 / 24 mobile | Bold | Screen titles |
| `title` | 22 | Semibold | Section / feature titles |
| `title2` | 18 | Semibold | Card titles, chat names |
| `headline` | 17 | Semibold | Row titles, emphasis |
| `body` | 17 | Regular | Main reading / messages |
| `callout` | 15 | Regular | Secondary body |
| `subheadline` | 15 | Regular | Meta, secondary |
| `footnote` | 13 | Medium | Timestamps, hints (`label-md`) |
| `caption` | 11–12 | Semibold | Tiny labels (`label-sm`) |
| `button` | 17 | Medium | Button labels |

### Rules

- Prefer Dynamic Type (`Font.body`, `.headline`, …) over fixed sizes when possible.
- Headlines: slightly tight tracking is ok; keep soft, not shouty.
- This is an **app**, not a marketing site — avoid huge 48–80pt display type.

---

## 4. Spacing & Radius

### Spacing scale (4pt baseline)

| Token | Value | Use |
|-------|-------|-----|
| `xxs` | 4 | Tight icon gaps; same-sender bubble gap |
| `xs` | 8 | Inline spacing |
| `sm` | 12 | Compact stacks (app convenience; brief often uses 8) |
| `md` | 16 | Default padding; different-sender bubble gap |
| `lg` | 24 | Section padding |
| `xl` | 32 | Large section gaps |
| `xxl` | 48 | Screen top breathing room |
| `screenHorizontal` | **20** | **Everywhere** — default side margin (mobile). Do not invent 16/24 screen gutters. |

### Corner radius

| Token | Value | Use |
|-------|-------|-----|
| `radiusSm` | 8 | Small tags / tight controls |
| `radiusMd` | 14 | Buttons, inputs, **default avatars (squircle)** |
| `radiusLg` | 18 | Bubbles, medium cards |
| `radiusXl` | 24 | Primary cards, sheets, large panels |
| `radiusFull` | Capsule | Chips, pill filters |

**Rule:** squircle-adjacent (`RoundedRectangle` + `.continuous`) for most interactive surfaces. Circles are allowed only where §0 lists them (Chats avatars, Connect Pass / Say Hi / Back).

---

## 5. Elevation & Depth

Depth = tonal layering + low-contrast outlines. Not heavy Material shadows.

| Level | Treatment |
|-------|-----------|
| 0 Canvas | `canvas` — no shadow |
| 1 Card / surface | `surface` + **1px `hairline`** — **default**; no shadow |
| 2 Floating | Soft diffused shadow: `0 / 4 / 20`, ~4% of `ink` — FAB / compose only |
| Elevated (rare) | Soft elevated shadow — Connect Discover hero deck only |
| Press | Dim or fill → `surfaceSoft` — do **not** lift |

**Rule:** hairline first; elevated shadow is rare. Do not put Level-2 / elevated shadows on ordinary list cards.

Overlay scrim behind modals: ~35–45% black.

---

## 6. Components

### Buttons

**Primary (default / low-impact)**
- Fill: `accentSoft`
- Text: `onPrimary` (`ink`)
- Radius: `radiusMd` (or Capsule for hero pills)
- Min height: 48–56
- Pressed → slightly dim
- Disabled → `surfaceSoft` + `inkDisabled`

**Emphasis (solid clay)** — **rare**: FAB, Say Hi, high-impact CTAs only
- Fill: `primary`
- Text: `onPrimaryStrong` (white) **or** deep ink if contrast needs it
- Pressed → `primaryPressed`

**Secondary**
- Fill: `surface`
- Border: `hairline` / `hairlineStrong`
- Text: `ink`

**Tertiary / text**
- No fill
- Text: `ink` or `primary` for links

**Connect action row exception:** Pass / Say Hi / Back stay **circle** shaped (see §0). Say Hi may use solid clay; Pass / Back stay soft or secondary — shape is circle, not squircle.

**Auth exception:** “Sign in with Apple” stays system black + white (platform guideline).

### Inputs

- Background: `surface`
- Border: `hairline` → focus `primary` (1px)
- Radius: `radiusMd`
- Placeholder: `inkMuted` / `inkSecondary`
- Error: border `error`, helper `error`

### Cards

- Background: `surface`
- Radius: `radiusXl` (24)
- Padding: 16
- Border: 1px `hairline`
- Shadow: **off** unless floating / rare elevated hero
- Used for: Connect candidates, community tiles, grouped empty states

**Card rule:** cards are for interaction/grouping. Don't wrap everything in cards.

### Chips / interests / filters

- Unselected: `surfaceSoft` + `inkSecondary`
- Selected: `primarySoft` + `primary` text (or solid `primary` + dark label on Connect filters)
- Radius: Capsule
- Soft spring on select

### Avatars

- **Default (Profile / Connect / Communities):** squircle — corner radius `radiusMd` (14), continuous (`clAvatarClip` / `CLAvatar.shape()`)
- **Chats (list / thread / info):** **circle** — intentional (`clChatAvatarClip` / `CLAvatar.chatShape()`). Not a bug; do not convert the whole app to one shape.
- Soft placeholder fill: `surfaceSoft`
- Initials / icon: `inkSecondary`
- Overlapping group stacks outside Chats may still use the squircle mask.

### Tab bar

- Background: `surface` (blur/system ok)
- Selected: `primary` or `primaryPressed` (icon + label)
- Unselected: `inkMuted`
- Keep system tab feel — no exotic floating tab bar unless a screen explicitly requires it

### Chat bubbles

| Role | Fill | Text |
|------|------|------|
| Mine (outbound) | `accentSoft` or `primarySoft` (or `surface` + hairline) | `ink` |
| Theirs (inbound) | `surfaceSoft` | `ink` |

- Radius: 18; tighter origin corner (~12) instead of comic tails
- Same sender gap: 4; different sender / system: 16

### FAB / compose

- Size ~56
- Shape: rounded square (`radiusLg`–`radiusXl`)
- Fill: `primary`; icon: `onPrimaryStrong`
- Floating shadow (Level 2) — rare elevated treatment

### Lists

- `hairline` separators inset ~16 from the leading edge (clear avatar)
- Unread: small `primary` dot — not a loud banner

### Navigation

- Titles in `ink` (or `primary` when the mock intentionally brands the title, e.g. Chats)
- System back chevron
- Avoid heavy custom nav chrome

#### Nav title policy (canonical)

| Mode | When | Where |
|------|------|--------|
| **Large** | Tab root that is a calm scroll hub, no crowded trailing toolbar | Communities, Profile |
| **Inline (system)** | Push / secondary screens, or a tab root with trailing toolbar chrome | Connect + all push destinations (Settings, Edit Profile, Liked You, Matches, Chat Info, Community Detail, …) |
| **Clay principal** | Branded tab root only — custom `.principal` title in `primary` | **Chats** list root only |

Rules:

- Do **not** invent clay principal titles on other tabs “for brand.”
- Prefer system `navigationTitle` over custom principal chrome unless this table says otherwise.
- Auth / Age Gate / Profile Setup stay **inline** (onboarding, not main-tab hubs).

---

## 7. Screen Patterns (CircleLink)

### Auth / Age gate
- Centered calm composition on parchment
- One headline, one short supporting line, CTAs stacked
- Apple = black system button; Email = secondary hairline
- Side padding: `screenHorizontal` (20)

### Profile setup
- Soft progress feel
- Interest chips with clay soft selection
- Soft CTA (`accentSoft` + ink) pinned above home indicator

### Communities
- Soft list or gentle hairline cards
- Selected / joined uses `primarySoft`, not loud solid blocks
- Avatars: squircle

### Connect
- Large candidate card (`radiusXl`), generous photo area
- **Hero card content:** name + age only — **no bio on the card**; bio lives in About
- Pass / Say Hi / Back action row — **circle** buttons; Say Hi = solid clay (rare emphasis)
- Filter chips above tab bar
- Empty state: warm, short copy, one next step
- Elevated shadow only on the Discover hero deck (rare)

### Chat list
- Clean rows, inset hairline separators
- **Circle** avatars (intentional); unread clay dot
- Optional FAB compose (floating)

### Chat thread
- `canvas` background
- Soft bubbles + comfortable spacing
- **Circle** peer avatars where shown
- Composer: rounded `surface`, clay send when active

### Profile
- Calm hierarchy: squircle avatar → name → interests → actions
- Destructive actions quieter until confirmed

### Community feed (design-ready)
- Feed cards on parchment; hairline cards; clay accents for actions
- Implement feature logic before visual pass if data is missing

---

## 8. Motion

Goal: **smooth and soft**, never flashy.

| Interaction | Preferred motion |
|-------------|------------------|
| Screen appear | Soft fade / short opacity |
| Cards / candidates | Spring + slight scale `0.96 → 1.0` |
| Sheets / modals | System sheet + soft spring |
| Chip select | Quick spring (background + scale micro) |
| Tab switch | System default |
| Button press | Opacity / fill dim — **no lift** |

### Suggested springs

```swift
// Default UI
Animation.spring(response: 0.35, dampingFraction: 0.82)

// Softer / larger surfaces
Animation.spring(response: 0.45, dampingFraction: 0.86)

// Micro (chips, buttons)
Animation.spring(response: 0.28, dampingFraction: 0.78)
```

### Don't

- Linear snappy snaps for cards
- Bounce-for-fun overshoot on every transition
- Continuous shimmer / glow loops as decoration
- Parallax-heavy motion that hurts readability

Respect Reduce Motion: fall back to simple fades.

---

## 9. Do / Don't

### Do
- Parchment canvas `#FCF9F8`
- Sunset Clay `#E67E5F` for accents
- Soft CTAs (`accentSoft` + ink) by default
- Hairline cards (24 radius); squircle avatars outside Chats
- Circle avatars in Chats; circle Connect Pass / Say Hi / Back
- `screenHorizontal` = 20 everywhere
- Hairline depth first; elevated shadow rare
- SF Pro + soft springs

### Don't
- Purple/indigo “AI default” themes
- Dark cinematic UI as default
- Hard corners on buttons/cards
- Heavy multi-layer shadows on every card
- Circle avatars as the **system default** (Chats exception only)
- Convert Chats circles or Connect action circles to squircle “for consistency”
- Put bio on the Connect Discover hero card
- Solid clay as the everyday CTA
- Giant marketing display type inside app screens
- Embed Inter font files

---

## 10. Accessibility

- Soft CTAs use dark ink on `accentSoft` / `primarySoft` (not white on light peach)
- Solid clay: prefer white label (`onPrimaryStrong`) and check contrast
- Min tap target: 44×44
- Support Dynamic Type for body/chat text
- Don't rely on color alone for state (pair with label/icon)
- Honor Reduce Motion

---

## 11. Agent Prompt Guide

When generating or editing UI:

1. Read `DESIGN.md` first — especially §0 Design Rules.
2. Use tokens above (names + hex) via `CLColor` / `CLTheme`.
3. Prefer SwiftUI system fonts and soft springs.
4. Map flow: User action → View → ViewModel → … → UI update, without putting design logic in Domain.
5. Keep screens light-first, parchment + clay, rounded, calmly animated.
6. Do not unify all avatars/buttons to one shape — respect §0 exceptions.

**Short prompt:**  
“Build this CircleLink screen using DESIGN.md §0: parchment `#FCF9F8`, clay `#E67E5F`, soft CTA `accentSoft`+ink, cards radius 24 + hairline, squircle avatars (circle only in Chats), Connect Pass/Say Hi/Back = circles, screenHorizontal 20, SF Pro, spring motion.”

---

## Sources

- Stitch brief: **Sunset Parchment** (`stitch_circlelink_visual_redesign_brief`)
- Material-style color YAML in the export is mapped into the simpler CL tokens above for SwiftUI
- SF Pro replaces Inter on iOS
