---
id: adr-design-adopt-sunset-parchment
title: Adopt Sunset Parchment
type: decision
status: implemented
date: 2026-08-06
tags: [design, swiftui, accessibility]
sources:
  - git:14bfdcc
  - legacy:DESIGN.md
---

# Adopt Sunset Parchment

## Context

CircleLink needed a coherent native identity across authentication, communities, Connect, Chats,
and Profile.

## Decision

Use the Sunset Parchment design system: warm parchment canvas, white surfaces, restrained clay
accent, soft squircles, SF Pro, hairline-first depth, gentle motion, and accessible semantic tokens.
Solid clay remains rare. Connect action buttons stay circular, while profile avatars use squircles.

## Consequences

New UI must use shared tokens and follow intentional exceptions rather than local screen styling.
Accessibility, Dynamic Type, minimum touch targets, and Reduce Motion are part of the design
contract.

## Sources

- [Design system](../../design/design-system.md)
- Adoption commit `14bfdcc` and canonical-rule commit `9e4dda4`.
- `CircleLink/Shared/Design/CLTheme.swift`.
