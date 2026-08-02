# Phase 27 — Slim CommunitiesListView (one screen)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Thin `CommunitiesListView` by extracting search/filter chrome, category UI, create sheet wiring, and navigation destination assembly.

## Why

~309 LOC combining list, filters, create community sheet, and detail navigation factories.

## Context

- `Features/Communities/CommunitiesListView.swift`
- `CreateCommunitySheet.swift`, `CommunitiesViewModel`
- Factories for detail/feed VMs from composition root
- Prefer after phase 22 for empty/error

## Scope

1. Extract list content / toolbar / filter sections into child Views.
2. Keep `navigationDestination` factories behavior the same.
3. No ViewModel API redesign unless required for compile after extract.

## Out of scope

- CommunityDetail slim (phase 25)
- Create community business rules changes
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-27-slim-communities-list-view`.
2. Extract → build → checklist: search, create, open detail.

## Acceptance criteria

- [ ] List view is clearer / thinner
- [ ] Create + navigate to detail still work
- [ ] Build passes
