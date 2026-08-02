# Phase 28 — Slim ProfileView (one screen)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Thin `ProfileView` by extracting profile header, interests editing chrome, settings entry, and avatar sections into child Views. Behavior unchanged.

## Why

~300 LOC mixing display, edit affordances, navigation to settings, push handler plumbing, and form-like UI.

## Context

- `Features/Profile/ProfileView.swift`
- `ProfileSetupView.swift` / edit flows only if they share extractable pieces (don’t expand unless obvious duplication)
- `ProfileViewModel`, settings route
- `DESIGN.md`

## Scope

1. Extract visual sections under `Features/Profile/`.
2. Keep DI for push/settings as currently wired (phases 3/20 may have cleaned factories — use current patterns).
3. No avatar storage changes (phase 9/23).

## Out of scope

- PeerProfile (phase 20)
- ProfileViewModel UIImage coupling fix beyond what’s needed to extract Views
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-28-slim-profile-view`.
2. Extract → build → checklist: view profile, edit/save entry, open settings, sign out if present.

## Acceptance criteria

- [ ] ProfileView thinner / sectional
- [ ] Edit/settings entry points unchanged
- [ ] Build passes
