---
name: Sunset Parchment
colors:
  surface: '#fcf9f8'
  surface-dim: '#dcd9d9'
  surface-bright: '#fcf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f2'
  surface-container: '#f0eded'
  surface-container-high: '#eae7e7'
  surface-container-highest: '#e5e2e1'
  on-surface: '#1c1b1b'
  on-surface-variant: '#55423d'
  inverse-surface: '#313030'
  inverse-on-surface: '#f3f0ef'
  outline: '#88726c'
  outline-variant: '#dcc1b9'
  surface-tint: '#9b442a'
  primary: '#9b442a'
  on-primary: '#ffffff'
  primary-container: '#e67e5f'
  on-primary-container: '#601a03'
  inverse-primary: '#ffb59f'
  secondary: '#665c58'
  on-secondary: '#ffffff'
  secondary-container: '#ebddd7'
  on-secondary-container: '#6a615c'
  tertiary: '#5e5e5d'
  on-tertiary: '#ffffff'
  tertiary-container: '#9b9b99'
  on-tertiary-container: '#323332'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbd1'
  primary-fixed-dim: '#ffb59f'
  on-primary-fixed: '#3a0a00'
  on-primary-fixed-variant: '#7c2d15'
  secondary-fixed: '#ede0da'
  secondary-fixed-dim: '#d1c4be'
  on-secondary-fixed: '#211a17'
  on-secondary-fixed-variant: '#4e4541'
  tertiary-fixed: '#e3e2e0'
  tertiary-fixed-dim: '#c7c6c5'
  on-tertiary-fixed: '#1a1c1b'
  on-tertiary-fixed-variant: '#464746'
  background: '#fcf9f8'
  on-background: '#1c1b1b'
  surface-variant: '#e5e2e1'
typography:
  display:
    fontFamily: Inter
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: -0.4px
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.4px
  headline-md:
    fontFamily: Inter
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.4px
  body-lg:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: -0.4px
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: -0.2px
  label-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: 0px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 13px
    letterSpacing: 0.06px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 40px
---

## Brand & Style
The design system focuses on a "Soft-Native" aesthetic—a refinement of standard iOS patterns that prioritizes emotional calm and interpersonal warmth. It targets a community-oriented audience seeking a low-stress alternative to hyper-stimulating social platforms.

The style is a blend of **Minimalism** and **Tactile Modernism**. It leverages expansive white space, a limited but warm color palette, and high-quality "Parchment" surfaces. The visual narrative rejects harsh shadows and pure blacks in favor of organic tones and soft hairlines, creating a digital environment that feels as tactile and approachable as high-end stationery.

## Colors
This design system utilizes a warm, analog-inspired palette. The foundation is **Parchment (#FAF9F7)**, which provides a softer, less straining background than pure white. **Sunset Clay (#E67E5F)** serves as the primary accent, used sparingly to guide focus without overwhelming the senses.

Functional colors (success/error) are desaturated to maintain the calm atmosphere. **Hairline (#E8E4DF)** is the critical structural color, used for dividers and borders to provide definition without the visual weight of traditional shadows or dark strokes.

## Typography
The system follows a strict iOS-inspired hierarchy using **Inter** (as the closest web/cross-platform equivalent to SF Pro). The scale is designed for high legibility in messaging contexts.

- **Headlines:** Use tighter letter spacing and semi-bold to bold weights to create a sense of grounded authority.
- **Body Text:** Standardized at 17pt for primary reading (messages) and 15pt for secondary info, ensuring comfort over long reading periods.
- **Labels:** Used for timestamps and metadata, often paired with `inkSecondary` to recede in the visual hierarchy.

## Layout & Spacing
The layout model is based on a **Fluid Grid** with generous safe areas. For mobile, a 20px side margin is preferred to give content "room to breathe," enhancing the airy feel.

Spacing follows a 4px baseline shift but favors larger increments (16px, 24px) to prevent the UI from feeling cluttered. Message threads should utilize dynamic vertical spacing: 4px between bubbles from the same sender, and 16px between different senders or system messages.

## Elevation & Depth
Depth is conveyed primarily through **Tonal Layering** and **Low-Contrast Outlines** rather than heavy shadows.

- **Level 0 (Canvas):** The #FAF9F7 background.
- **Level 1 (Cards/Surfaces):** #FFFFFF surfaces used for primary content containers. These use a 1px `hairline` border to define edges against the canvas.
- **Level 2 (Active/Floating):** Use an extremely soft, diffused shadow (0px 4px 20px, 4% opacity of `ink`) only for high-priority floating elements like Compose buttons.
- **Interactions:** Elements do not "lift" on press; instead, they slightly dim or change fill color to `surfaceSoft`.

## Shapes
The shape language is "Squircle-adjacent," favoring large radii that evoke a sense of safety and softness. 

- **Primary Containers:** 18pt to 24pt corners for cards and large modal surfaces.
- **Interactive Elements:** 14pt corners for buttons and avatars.
- **Message Bubbles:** 18pt corners, with "tails" replaced by slightly tighter radii on the origin corner to maintain a modern, clean look.

## Components
- **Buttons:** Primary buttons use `primarySoft` background with `ink` text. This "low-impact" primary style reduces visual fatigue. Use `capsule` shapes for action triggers and `rounded-lg` for inline actions.
- **Avatars:** Strictly 14pt rounded squares. Do not use circles, as the "squircle" look feels more tailored and premium.
- **Input Fields:** Use `surface` fill with a `hairline` border. Placeholder text should use `inkSecondary`. Focused states should transition the border to `primary` at 1px width.
- **Chips:** Used for filters or tags. Default state is `surfaceSoft`; selected state is `primarySoft` with `primary` text.
- **Chat Bubbles:**
    - **Inbound:** `surfaceSoft` fill, `ink` text, left-aligned.
    - **Outbound:** `primarySoft` fill or `surface` with `hairline`, `ink` text, right-aligned. 
- **Cards:** White (#FFFFFF) background, 24pt radius, with a 1px `hairline` border. No shadow unless floating.
- **Lists:** Use `hairline` separators that inset 16px from the left to clear the icon/avatar, following native iOS patterns.