---
id: adr-connect-contextual-guide-system
title: Contextual Guide System
type: decision
status: implemented
date: 2026-09-06
tags: [connect, onboarding, guides, accessibility]
sources:
  - git:8cccc2e
---

# Contextual Guide System

## Context

Guide overlays need to target SwiftUI and UIKit content without appearing before navigation,
loading, geometry, sheets, keyboard, or accessibility state has settled.

## Decision

Use a coordinator-owned `ContextualGuideManager`, semantic guide targets, screen visits,
generation-scoped layout reports, presentation blockers, safe-bound placement, persisted versioned
completion, manual replay, and accessibility coordination. A target becomes eligible only after its
screen and content report stable geometry.

Feature-owned tutorials may suspend a guide without completing it. Suspension persists across
layout reconciliation until feature completion or explicit abandonment.

## Consequences

Guides are consistent and replayable, but feature transitions must correctly manage readiness,
blocking, suspension, and completion. Layout and lifecycle behavior require focused tests.

## Sources

- [Connect](../../product/connect.md)
- Foundation commit `8cccc2e` and stabilization commit `6340b52`.
- `CircleLink/Shared/Guides/`.
