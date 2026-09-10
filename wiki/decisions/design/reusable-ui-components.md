---
id: adr-design-reusable-ui-components
title: Reusable UI Component Boundaries
type: decision
status: implemented
date: 2026-09-04
tags: [design, engineering, components]
sources:
  - git:b50de64
  - git:e66ede5
  - legacy:UI_COMPONENTS_MIGRATION_CHECKLIST.md
---

# Reusable UI Component Boundaries

## Context

Repeated forms, rows, surfaces, media, navigation, and feedback patterns were drifting across
features.

## Decision

Cross-feature primitives live in `Shared/Design`; feature-specific reusable components stay under
their feature's `Components` directory. Existing feature-owned interaction logic and the UIKit chat
thread remain local. Shared components implement semantic tokens and accessibility centrally.

## Consequences

Features gain consistency without forcing specialized behavior into a generic abstraction. New
local primitives require checking the shared library first.

## Sources

- [UI component organization](../../engineering/ui-components.md)
- Foundation commit `b50de64`, adoption commit `e66ede5`, and documentation commit `91985b7`.
