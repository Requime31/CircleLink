---
title: UI Component Organization
type: engineering
status: current
updated: 2026-09-11
tags: [engineering, design-system, components]
---

# UI Component Organization

Cross-feature presentation primitives live under `CircleLink/Shared/Design`. Feature-specific
reusable components stay under `CircleLink/Features/<Feature>/Components`. UIKit chat appearance
remains isolated in the chat feature rather than being forced into the SwiftUI component library.

The component adoption pass covered auth, age gate, profile, communities, Connect, Chats,
settings, legal screens, common media, rows, forms, navigation, state, and feedback. Feature-owned
interaction logic such as Connect swipe controls and chat thread chrome remains feature-local.

New UI should use existing `CL*` types and the design tokens before introducing another local
abstraction. Shared components must preserve Dynamic Type, accessibility semantics, minimum touch
targets, and predictable parent-owned layout.

## Related decision

- [Reusable UI components](../decisions/design/reusable-ui-components.md)

## Sources

- Legacy `UI_COMPONENTS_MIGRATION_CHECKLIST.md`, migrated during bootstrap.
- `CircleLink/Shared/Design/` and feature `Components/` directories.
- Git history from `b50de64` through `91985b7`.
