# DESIGN_SYSTEM.md — visual memory (Sunset Parchment)

**Source of truth:** root [`DESIGN.md`](../../DESIGN.md).  
This file is a short working memory for agents. If anything conflicts, **follow `DESIGN.md`**.

Stitch brief (screen PNGs / HTML):  
`/Users/romanshevchenko/Desktop/iOS/stitch_circlelink_visual_redesign_brief`  
(see `.cursor/rules/ui-redisign-design-source.mdc`)

Swift tokens: `CircleLink/Shared/Design/CLTheme.swift` (`CLColor`, `CLSpacing`, `CLRadius`, …).

Related: [AGENTS.md](AGENTS.md) · [DECISIONS.md](DECISIONS.md)

---

## Theme in one line

Warm **parchment** canvas + white surfaces + **Sunset Clay** accent — soft-native, light-first, calm hierarchy.

---

## §0 exceptions (do not “fix”)

| Rule | Spec |
|------|------|
| Default avatars | **Squircle** (`radiusMd` / continuous) — Profile, Connect, Communities |
| Chats avatars | **Circle** — list / thread / chat info |
| Connect action row | Pass / Say Hi / Back = **circle** buttons |
| Connect Discover hero | **Name + age only** on the card; bio in About |
| Default CTA | Soft: `accentSoft` + `ink` (or secondary hairline) |
| Solid clay CTA | **Rare** — FAB, Say Hi, unread accents |
| Horizontal inset | `screenHorizontal` = **20** |
| Shadows | Hairline first; elevated / floating shadow is rare |

---

## Core colors (hex)

| Token | Hex | Role |
|-------|-----|------|
| `canvas` | `#FCF9F8` | Screen background |
| `surface` | `#FFFFFF` | Cards, sheets, inputs |
| `surfaceSoft` | `#F6F3F2` | Muted rows / groups |
| `hairline` | `#E8E4DF` | Borders / dividers |
| `ink` | `#1C1B1B` | Primary text |
| `inkSecondary` | `#55423D` | Secondary |
| `inkMuted` | `#88726C` | Captions / meta |
| `primary` | `#E67E5F` | Sunset Clay accent |
| `accentSoft` | `#F8E6E0` | **Default soft CTA** fill |
| `primarySoft` | `#FFDBD1` | Selected chips / stronger soft |
| `onPrimary` | `#1C1B1B` | Label on soft fills |
| `onPrimaryStrong` | `#FFFFFF` | Label on solid clay |

Never use purple as brand accent. No neon / glow.

---

## Spacing & radius

**Spacing (4pt baseline):** `xxs` 4 · `xs` 8 · `sm` 12 · `md` 16 · `lg` 24 · `xl` 32 · `xxl` 48 · **`screenHorizontal` 20**.

**Radius:** `sm` 8 · `md` 14 (buttons, inputs, default squircle avatars) · `lg` 18 (bubbles) · `xl` 24 (cards/sheets) · Capsule for chips.

---

## Components (quick)

- **Buttons:** soft CTA by default; solid clay rare; Connect Pass/Say Hi/Back stay circles; Sign in with Apple stays system black.
- **Cards:** `surface` + `radiusXl` (24) + 1px hairline; shadow off unless floating / Connect hero deck.
- **Chips:** Capsule (`CLChip`); unselected `surfaceSoft`; selected `primarySoft` + clay text.
- **Avatars:** squircle default; **circle only in Chats** (and Connect action circles as above). No decorative circle clay badge on Profile squircle avatar.
- **Chat bubbles:** soft fills; radius ~18; same-sender gap 4, different 16.
- **Tab bar:** system feel; selected clay; unselected `inkMuted`. Profile tab uses `person` (not `person.circle`).
- **Typography:** SF Pro (system). Do not embed Inter.

### Nav titles

| Mode | Where |
|------|--------|
| **Large** | Communities, Profile (calm tab hubs) |
| **Inline** | Connect + all push/secondary screens |
| **Clay principal** | Chats root only |

Full table: `DESIGN.md` → Navigation → Nav title policy.

---

## Motion

Soft springs, dim on press — no lift, no flashy bounce. Respect Reduce Motion.

Suggested defaults (from `DESIGN.md`):

- UI: `spring(response: 0.35, dampingFraction: 0.82)`
- Larger: `0.45 / 0.86`
- Micro: `0.28 / 0.78`

---

## Agent checklist before UI edits

1. Read `DESIGN.md` §0.
2. Open Stitch `screen.png` for that screen when doing redesign work.
3. Use `CLColor` / `CLSpacing` / `CLRadius` — don’t invent one-off hex.
4. Keep design logic out of Domain.
5. Do not unify all shapes “for consistency.”
