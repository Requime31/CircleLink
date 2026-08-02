# Phase 29 — Slim ChatInfoView (one screen)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Thin `ChatInfoView` by extracting participants list, leave/actions section, and loading/error host. Behavior unchanged.

## Why

~254 LOC; smaller than others but still mixes list UI, leave confirmation, and navigation to peer profiles.

## Context

- `Features/ChatList/ChatInfoView.swift`
- `ChatInfoViewModel`
- Prefer after phase 13 (leave dedupe) and phase 22

## Scope

1. Extract subviews under ChatList feature folder.
2. Keep leave confirmation UX the same.
3. Peer profile presentation should use the standardized factory if phase 20 landed; otherwise don’t widen scope.

## Out of scope

- Chat UIKit thread
- Repository changes
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-29-slim-chat-info-view`.
2. Extract → build → checklist: participants, leave, open peer if available.

## Acceptance criteria

- [ ] ChatInfoView easier to read
- [ ] Leave + participants still work
- [ ] Build passes
