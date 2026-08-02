# Phase 24 — Slim ConnectView (one screen)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Reduce `ConnectView` complexity by extracting subviews / destination routing helpers. **No product redesign.** ViewModel split is phase 5 — don’t redo it here unless already done; just make the View readable.

## Why

`ConnectView` (~375 LOC) mixes layout, typed navigation destinations, sheets, and child screen wiring. Hard to review; easy to break navigation.

## Context

- `Features/Connect/ConnectView.swift` (+ related Connect screens)
- ViewModel(s): `ConnectViewModel` or split VMs from phase 5
- `DESIGN.md` for any UI extraction that still renders UI
- Prefer after phase 5 and phase 22 if available; can proceed alone carefully

## Scope

1. Extract private destination / sheet content into focused SwiftUI files under `Features/Connect/`.
2. Keep navigation behavior identical (`navigationDestination`, sheets, callbacks).
3. Move bulky section builders into small child Views (deck entry, inbox entry, matches entry) if they live inline.
4. Do not invent a new navigation architecture (tab routers = phase 32).

## Out of scope

- ConnectViewModel responsibility split (phase 5)
- Connect async ownership (phase 16)
- Changing Connect UX/copy
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-24-slim-connect-view`.
2. Map sections of ConnectView → target files.
3. Extract → build → smoke navigation paths in summary checklist.

## Acceptance criteria

- [ ] `ConnectView.swift` clearly thinner / assembler-like
- [ ] Same navigation + sheets
- [ ] Build passes
