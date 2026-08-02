# Phase 30 — Split PushNotificationHandler (internal)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Break `PushNotificationHandler` (~251 LOC) into focused collaborators while keeping a small facade for AppDelegate / coordinator wiring. Settings protocol from phase 3 should remain the presentation-facing API.

## Why

One type mixes: permission requests, preference reads, UNUserNotificationCenter actions, Firebase Messaging token lifecycle, Firestore token persistence, deep-link parse/forward.

## Context

- `App/PushNotificationHandler.swift`
- `App/PushDeepLink.swift`
- `AppDelegate.swift`, `AppCoordinator.swift`
- Phase 3: `NotificationSettingsServing` (or equivalent) — presentation should keep using the protocol
- Docs: `ARCHITECTURE.md` push section

## Suggested split

- Permission / settings service (conforms to phase 3 protocol)
- FCM token registrar (get token → persist via UserRepository / focused writer)
- Notification response → `PushDeepLink` router forwarder
- Facade `PushNotificationHandler` delegates to the above

## Scope

1. Extract collaborators under `App/` (or `App/Push/`).
2. Keep external call sites compiling with minimal churn (`AppDelegate.attach`, coordinator `onDeepLink`).
3. No change to FCM payload contract / server.
4. Don’t move token field onto Domain `User` model.

## Out of scope

- Settings UI
- websocket-server / Cloud Functions
- Tab navigation redesign
- Commit / push / PR unless user asks

## Process

1. Propose type boundaries first.
2. Branch: `phase-30-split-push-handler`.
3. Extract → build → checklist: permission, token save, tap opens deep link.

## Acceptance criteria

- [ ] Handler is a facade or clearly separated types
- [ ] Settings still works via protocol (phase 3)
- [ ] Deep link tap path intact
- [ ] Build passes

## Data flow (unchanged externally)

FCM tap → AppDelegate → response handler → `PushDeepLink` → AppCoordinator.handleDeepLink → UI route
