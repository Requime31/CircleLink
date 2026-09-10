---
title: Sunset Parchment Design System
type: design
status: current
updated: 2026-09-11
tags: [design, swiftui, accessibility]
---

# Sunset Parchment Design System

CircleLink uses a light-first, soft native visual system: parchment canvas, white surfaces,
low-contrast hairlines, restrained Sunset Clay accents, SF Pro, comfortable whitespace, and
subtle motion.

## Canonical tokens

- Canvas `#FCF9F8`; surface `#FFFFFF`; soft surface `#F6F3F2`.
- Hairline `#E8E4DF`; strong hairline `#DCC1B9`.
- Ink `#1C1B1B`; secondary ink `#55423D`; muted ink `#88726C`.
- Primary clay `#E67E5F`; pressed/strong clay `#9B442A`.
- Soft action fills `#F8E6E0` and `#FFDBD1`.
- Horizontal screen inset is 20 points. Spacing follows a four-point baseline.
- Default control radius is a 14-point continuous squircle; cards commonly use 24 points.

Use semantic `CLColor`, `CLTypography`, `CLSpacing`, and `CLRadius` tokens instead of literal
values in feature UI.

## Component rules

- Default calls to action use a soft clay fill and dark ink. Solid clay is reserved for high
  emphasis such as Say Hi, unread emphasis, and floating compose actions.
- Ordinary cards use a surface plus hairline, not a floating shadow. Connect's hero deck is a
  deliberate elevated exception.
- Profile avatars use continuous squircles, including Chats.
- Connect Pass, Say Hi, and Back actions remain circles as an intentional exception.
- Connect hero cards show name and age; biography belongs in the About section.
- System navigation titles are preferred. Communities and Profile may use large titles; Connect
  and push destinations use inline titles; Chats keeps a static content header.
- Auth keeps the platform black Sign in with Apple treatment.

## Motion and accessibility

Use short soft springs or fades, avoid decorative continuous animation, and respect Reduce
Motion. Support Dynamic Type, maintain 44-point minimum targets, preserve text contrast, and never
encode state by color alone.

## Related decisions

- [Adopt Sunset Parchment](../decisions/design/adopt-sunset-parchment.md)
- [Reusable UI components](../decisions/design/reusable-ui-components.md)

## Sources

- Legacy `DESIGN.md`, migrated during bootstrap.
- `CircleLink/Shared/Design/`.
- Git history: `14bfdcc`, `9e4dda4`, and the reusable-component series ending at `91985b7`.
