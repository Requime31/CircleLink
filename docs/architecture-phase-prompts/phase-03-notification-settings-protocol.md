# Phase 3 — Notification settings protocol (stop leaking PushNotificationHandler)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Introduce a small protocol for notification settings so presentation / Settings ViewModel do not depend on the concrete `PushNotificationHandler`.

## Why

`PushNotificationHandler` (~251 LOC) mixes permissions, FCM token, Firestore writes, and deep links. It is injected as a concrete type into `MainTabView`, `ProfileView`, `SettingsView` / `SettingsViewModel`. That makes Settings hard to unit test and leaks infrastructure into Features.

## Context

- Concrete: `CircleLink/App/PushNotificationHandler.swift`
- Settings: `CircleLink/Features/Settings/SettingsView.swift`, `SettingsViewModel.swift`
- Wiring: `AppDependencies.swift`, `AppCoordinator.swift`, `MainTabView.swift`, `ProfileView.swift`
- Possibly `AppDelegate.swift`
- Docs: `ARCHITECTURE.md`

## Scope (do only this)

1. Define a focused protocol (name suggestion: `NotificationSettingsServing` or similar) with **only** what Settings/UI need (e.g. authorization status, enable/disable, open system settings). Do **not** put deep-link or full FCM lifecycle on this protocol unless Settings already needs it.
2. Make `PushNotificationHandler` conform (or wrap it with a thin adapter).
3. Inject the protocol into Settings ViewModel (and any View that only needs settings APIs).
4. Prefer creating Settings VM in composition root / factory (like other VMs), instead of `SettingsView` constructing it from a concrete handler — if that fits without a large navigation rewrite.
5. Add/adjust mocks + a small `SettingsViewModel` test if cheap.

## Out of scope

- Rewriting all of push / deep link pipeline
- Changing FCM server / token storage schema
- Chat / Connect refactors
- Commit / push / PR unless user asks

## Design constraints

- Keep the protocol tiny — avoid a second god interface.
- Domain vs App placement: if the protocol is app-infrastructure, putting it next to push code or under Domain/Repositories is a tradeoff — choose one and explain WHY.
- No new third-party libs.

## Process

1. Propose protocol surface + file placement first (short), then implement.
2. Branch: `phase-3-notification-settings-protocol`.
3. Build + run Settings-related tests (add if missing and small).

## Acceptance criteria

- [ ] Settings ViewModel depends on a protocol, not `PushNotificationHandler` directly
- [ ] Live app still toggles notification permission / opens settings
- [ ] Mockable in tests
- [ ] No unrelated refactors

## Data flow after change

User toggles notifications → SettingsView → SettingsViewModel → `NotificationSettingsServing` → `PushNotificationHandler` (Data/App) → system / FCM → status update → UI
