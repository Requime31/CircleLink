# CircleLink — DESIGN.md

> Soft, warm, modern UI for a community messenger.  
> Inspired by Notion (warm surfaces, calm hierarchy) + Airbnb (friendly rounding, human feel).  
> Adapted for **SwiftUI / iOS**, not web.

Use this file as the single source of truth for visual decisions.  
Before any UI work: read this file and follow it.

---

## 1. Visual Theme & Atmosphere

CircleLink should feel like a calm place to meet people — warm, soft, and approachable.

| Trait | Direction |
|-------|-----------|
| Mood | Warm, friendly, low-stress |
| Density | Comfortable whitespace; not dense dashboards |
| Surfaces | Soft warm neutrals, light elevation |
| Accent | Peach — used sparingly for primary actions |
| Motion | Spring-based, gentle; never snappy or flashy |
| Mode | Light-first (no dark-first UI in MVP) |

**Brand test:** screens should feel like CircleLink even without the logo — warm canvas + peach accent + soft cards.

---

## 2. Color Palette

### Core

| Token | Hex | SwiftUI role |
|-------|-----|----------------|
| `canvas` | `#FAF9F7` | Screen background |
| `surface` | `#FFFFFF` | Cards, sheets, inputs |
| `surfaceSoft` | `#F5F3F0` | Secondary groups, muted rows |
| `hairline` | `#E8E4DF` | Dividers, borders |
| `hairlineStrong` | `#D4CFC8` | Stronger borders / secondary buttons |

### Ink (text)

| Token | Hex | Use |
|-------|-----|-----|
| `ink` | `#1A1A1A` | Primary text |
| `inkSecondary` | `#5C574F` | Secondary labels |
| `inkMuted` | `#8A847A` | Captions, placeholders, meta |
| `inkDisabled` | `#B8B2A8` | Disabled text |

### Primary (Peach)

| Token | Hex | Use |
|-------|-----|-----|
| `primary` | `#F2A68A` | Primary CTA fill, selected accents |
| `primaryPressed` | `#E08B6C` | Pressed / highlighted |
| `primarySoft` | `#FDE8DE` | Soft chips, selected backgrounds |
| `primaryStrong` | `#E8926F` | Optional stronger CTA when white label is needed |
| `onPrimary` | `#1A1A1A` | Label on `primary` / `primarySoft` (dark for contrast) |
| `onPrimaryStrong` | `#FFFFFF` | Label only on `primaryStrong` |

### Soft tints (communities / interests)

Use lightly — never as full-screen backgrounds.

| Token | Hex | Use |
|-------|-----|-----|
| `tintPeach` | `#FDE8DE` | Default interest / soft highlight |
| `tintCream` | `#F8F1E7` | Empty / calm blocks |
| `tintMint` | `#E4F3EC` | Success-adjacent soft state |
| `tintRose` | `#F8E6EA` | Soft warning / attention |

### Semantic

| Token | Hex | Use |
|-------|-----|-----|
| `success` | `#3D9B6E` | Connected, sent, confirmed |
| `warning` | `#D4A017` | Caution |
| `error` | `#D94F4F` | Errors, destructive |
| `errorSoft` | `#FCEAEA` | Error background |

### Rules

- Peach is for **actions and selection**, not decoration everywhere.
- Prefer `primarySoft` for selected list rows / chips; reserve solid `primary` for main CTAs.
- Never use purple as brand accent.
- Never use neon / glow accents.

---

## 3. Typography (SwiftUI)

Use **SF Pro** (system). Do not embed web fonts (Notion Sans / Airbnb Cereal).

| Style | Size | Weight | Line | Use |
|-------|------|--------|------|-----|
| `largeTitle` | 28 | Semibold | tight | Screen titles (rare) |
| `title` | 22 | Semibold | 1.2 | Section / feature titles |
| `title2` | 18 | Semibold | 1.25 | Card titles, chat names |
| `headline` | 16 | Semibold | 1.3 | Row titles, emphasis |
| `body` | 16 | Regular | 1.45 | Main reading text |
| `callout` | 15 | Regular | 1.4 | Secondary body |
| `subheadline` | 14 | Regular | 1.35 | Meta, secondary |
| `footnote` | 13 | Regular | 1.3 | Timestamps, hints |
| `caption` | 12 | Medium | 1.25 | Badges, tiny labels |
| `button` | 16 | Medium | 1.2 | Button labels |

### Rules

- This is an **app**, not a marketing site — avoid huge 48–80pt display type.
- Prefer Semibold over Bold for titles (softer).
- Dynamic Type: respect system text styles where possible; don't lock tiny fixed sizes for body text.

---

## 4. Spacing & Radius

### Spacing scale

| Token | Value | Use |
|-------|-------|-----|
| `xxs` | 4 | Tight icon gaps |
| `xs` | 8 | Inline spacing |
| `sm` | 12 | Compact stacks |
| `md` | 16 | Default padding |
| `lg` | 24 | Section padding |
| `xl` | 32 | Large section gaps |
| `xxl` | 48 | Screen top breathing room |

Screen horizontal padding default: **16–20**.

### Corner radius

| Token | Value | Use |
|-------|-------|-----|
| `radiusSm` | 10 | Small controls, tags |
| `radiusMd` | 14 | Buttons, inputs |
| `radiusLg` | 18 | Cards |
| `radiusXl` | 24 | Sheets, large panels |
| `radiusFull` | Capsule / Circle | Chips, avatars, pill CTAs |

**Rule:** no hard 0° corners on interactive surfaces.

---

## 5. Elevation & Depth

Keep depth soft — Notion calm, not heavy Material shadows.

| Level | Treatment |
|-------|-----------|
| Flat | `canvas` / `surfaceSoft`, no shadow |
| Card | `surface` + very soft shadow (black ~8–12% opacity, y: 4–8, blur: 16–24) |
| Sheet / modal | `surface` + stronger soft shadow or system sheet |
| Overlay | Dim scrim ~35–45% black behind modals |

Prefer **hairline borders** (`hairline`) over heavy shadows when stacking list rows.

---

## 6. Components

### Buttons

**Primary**
- Fill: `primary`
- Text: `onPrimary`
- Radius: `radiusMd` or Capsule for hero CTAs
- Min height: 48
- Pressed → `primaryPressed`
- Disabled → `surfaceSoft` + `inkDisabled`

**Primary strong** (optional, when peach needs white text)
- Fill: `primaryStrong`
- Text: `onPrimaryStrong`

**Secondary**
- Fill: `surface`
- Border: `hairlineStrong`
- Text: `ink`

**Tertiary / text**
- No fill
- Text: `ink` or `primaryPressed` for links

### Inputs

- Background: `surface`
- Border: `hairline` → focus `primary`
- Radius: `radiusMd`
- Placeholder: `inkMuted`
- Error: border `error`, helper text `error`

### Cards

- Background: `surface`
- Radius: `radiusLg`
- Padding: 16
- Optional soft shadow
- Used for: Connect candidates, community tiles, empty states that need a container

**Card rule:** cards are for interaction/grouping. Don't wrap everything in cards.

### Chips / interests

- Unselected: `surfaceSoft` + `inkSecondary`
- Selected: `primarySoft` + `ink`
- Radius: Capsule
- Soft spring on select

### Avatars

- Circle
- Soft placeholder fill: `surfaceSoft`
- Initials: `inkSecondary`

### Tab bar

- Background: `surface` (blur/system ok)
- Selected: peach tint / `primary` icon+label
- Unselected: `inkMuted`
- Keep system tab feel — don't invent a floating exotic tab bar unless necessary

### Chat bubbles

| Role | Fill | Text |
|------|------|------|
| Mine | `primarySoft` | `ink` |
| Theirs | `surface` + hairline or `surfaceSoft` | `ink` |

Radius: 16–18, with a slightly tighter corner on the “tail” side if custom. Soft, not comic-style.

### Navigation

- Large or inline titles in `ink`
- Back chevron system-standard
- Avoid heavy custom nav chrome

---

## 7. Screen Patterns (CircleLink)

### Auth / Age gate
- Centered calm composition
- One headline, one short supporting line, one primary CTA
- Warm `canvas`, no busy illustrations required

### Profile setup
- Clear progress feel (soft)
- Interest chips with peach soft selection
- Primary CTA pinned comfortably above home indicator

### Communities
- Soft list or gentle cards
- Selected community uses `primarySoft`, not loud solid peach blocks

### Connect
- Candidate cards with generous photo/avatar space
- Primary actions obvious but not aggressive
- Empty state: warm, short copy, one next step

### Chat list
- Clean rows, soft separators (`hairline`)
- Unread accent: small peach dot or soft badge — not a loud banner

### Chat thread
- `canvas` or `surfaceSoft` background
- Soft bubbles, comfortable spacing
- Composer: rounded, `surface`, peach send when active

### Profile
- Calm hierarchy: avatar → name → interests → actions
- Destructive actions visually quieter until confirmed

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
| Button press | Opacity / slight scale down ~0.98 |

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
- Warm off-white canvas
- Peach for primary actions and selection
- Soft corners and soft springs
- Clear hierarchy with calm typography
- One primary CTA per screen section

### Don't
- Purple/indigo “AI default” themes
- Dark cinematic UI as default
- Hard corners on buttons/cards
- Neon accents, multi-layer glow shadows
- Dashboard clutter (stat strips, chip overload)
- Giant marketing display type inside app screens

---

## 10. Accessibility

- Contrast: dark text on peach (`onPrimary`), not white on light peach
- Min tap target: 44×44
- Support Dynamic Type for body/chat text
- Don't rely on color alone for state (pair with label/icon)
- Honor Reduce Motion

---

## 11. Agent Prompt Guide

When generating or editing UI:

1. Read `DESIGN.md` first.
2. Use tokens above (names + hex).
3. Prefer SwiftUI system fonts and soft springs.
4. Map flow: User action → View → ViewModel → … → UI update, without putting design logic in Domain.
5. Keep screens light-first, warm, peach-accented, rounded, calmly animated.

**Short prompt:**  
“Build this CircleLink screen using DESIGN.md: warm canvas `#FAF9F7`, peach primary `#F2A68A`, soft cards radius 18, SF Pro, spring motion.”

---

## Sources (inspiration only)

- Notion — warm neutrals, soft surfaces, calm text hierarchy  
- Airbnb — friendly rounding, human consumer feel, clear CTAs  

CircleLink tokens above are **project-specific** (peach primary, SwiftUI constraints). Do not copy Notion purple or Airbnb Rausch as brand colors.
