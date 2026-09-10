---
title: Architecture Overview
type: architecture
status: current
updated: 2026-09-11
tags: [architecture, ios, mvvm]
---

# Architecture Overview

CircleLink uses repository-driven MVVM with manual dependency injection.

```text
View → ViewModel → Repository protocol ← Data implementation
```

- `App` owns lifecycle, dependency composition, root navigation, and push routing.
- `Features` contains SwiftUI screens and the isolated UIKit chat thread.
- `Domain` contains Foundation-only models and repository protocols.
- `Data` contains Firebase, Supabase, Keychain, and stub implementations.
- `Shared` contains cross-feature utilities, design components, guides, images, and activity UI.

ViewModels run on `@MainActor`. They call repository protocols directly; there is no UseCase
layer. `AppDependencies` is the composition root and constructs concrete services. Realtime
listeners expose `AsyncStream` values and remove their Firestore registrations when streams end.

`AppCoordinator` owns bootstrap, authentication, recovery, age gate, profile setup, main tabs,
and external routes. Each tab owns a `NavigationStack`; cross-feature chat entry uses typed routes.

## Architectural rules

- UI never creates Firebase, Supabase, or Keychain clients.
- Domain imports no UI or provider frameworks.
- Every realtime listener has matching cancellation.
- Firestore messages are the only chat message source of truth.
- Birth date remains private; public data contains only derived age.
- Account deactivation remains reversible until an external cleanup process acts.
- UI work follows the maintained [design system](../design/design-system.md).

## Related decisions

- [Repository-driven MVVM](../decisions/architecture/repository-driven-mvvm.md)
- [Firebase and Supabase responsibilities](../decisions/backend/firebase-and-supabase-responsibilities.md)

## Sources

- Legacy `ARCHITECTURE.md`, migrated during bootstrap.
- `CircleLink/App/AppDependencies.swift` — `AppDependencies`.
- `CircleLink/App/AppCoordinator.swift` — `AppCoordinator`.
