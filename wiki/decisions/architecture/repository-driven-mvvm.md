---
id: adr-architecture-repository-driven-mvvm
title: Repository-Driven MVVM
type: decision
status: implemented
date: 2026-07-15
tags: [architecture, mvvm, dependency-injection]
sources:
  - git:5ccf241
  - legacy:ARCHITECTURE.md
---

# Repository-Driven MVVM

## Context

CircleLink needs testable presentation logic while integrating several provider SDKs. The MVP
does not need an additional domain orchestration layer for its current workflows.

## Decision

Views call `@MainActor` ViewModels. ViewModels depend on Domain repository protocols. Firebase,
Supabase, and Keychain implementations live in Data and are assembled manually by
`AppDependencies`. Domain imports Foundation only. The MVP intentionally has no UseCase layer.

## Consequences

Feature logic remains testable with mocks and provider details stay out of UI. ViewModels can grow
if workflows become more complex; a future orchestration layer should be introduced only for a
demonstrated need and through a superseding decision.

## Sources

- [Architecture overview](../../architecture/overview.md)
- Historical foundation commit `5ccf241`.
- `CircleLink/App/AppDependencies.swift` — `AppDependencies`.
