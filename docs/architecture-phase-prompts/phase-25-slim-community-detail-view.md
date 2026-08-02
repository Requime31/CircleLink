# Phase 25 — Slim CommunityDetailView (one screen)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Thin `CommunityDetailView` by extracting sections (header, members, feed host, membership actions, sheets) into focused SwiftUI views. Behavior unchanged.

## Why

~355 LOC mixing membership actions, chat open, feed embedding, peer sheets, and error/loading UI.

## Context

- `Features/Communities/CommunityDetailView.swift`
- VMs: `CommunityDetailViewModel`, `CommunityFeedViewModel`
- Related sheets: compose post, peer profile
- Prefer after phases 7/14/22 if done; don’t block on them

## Scope

1. Extract subviews under `Features/Communities/` (e.g. header, members list, action bar).
2. Keep factory-injected VMs and navigation callbacks as they are.
3. No repository / UseCase changes unless a binding bug forces a one-liner.

## Out of scope

- UseCase extraction (phase 7)
- Feed ViewModel logic
- Create-community flow
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-25-slim-community-detail-view`.
2. Extract → build → checklist: join/leave, open chat, open feed/post, peer profile.

## Acceptance criteria

- [ ] Detail view is assembler-thin enough to read quickly
- [ ] Membership + chat + feed entry still work
- [ ] Build passes
