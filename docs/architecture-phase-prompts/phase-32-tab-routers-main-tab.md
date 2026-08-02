# Phase 32 — Tab routers: shrink MainTabView dependency relay

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Reduce `MainTabView`’s giant parameter list by introducing **per-tab** lightweight routers/assemblers. Do not build a full Coordinator framework for the whole app.

## Why

`MainTabView` takes many ViewModels, factories, push handler, and callbacks — it’s a dependency relay. Hard to extend; hides navigation ownership.

## Context

- `Features/MainTabView.swift`
- `App/AppCoordinator.swift` (builds MainTabView)
- Tab roots: Communities, Chats, Connect, Profile
- Deep link / `pendingChatRoute` still must work
- Prefer after phases 10, 20, 26, 31 if available — integrate current wiring

## Recommended approach (minimal)

For each tab, a small type owned by App layer or Features:

```text
CommunitiesTabRouter / ChatsTabRouter / ...
```

Each holds what that tab needs (VM + factories) and exposes `rootView: some View`.

`MainTabView` then roughly becomes: tab selection + four router roots + shared bindings (`selectedTab`, `pendingChatRoute` if still needed).

Alternatively: one `MainTabAssembly` produced by `AppDependencies` / coordinator that MainTabView consumes as a single dependency. Choose the smaller diff; explain WHY.

## Scope

1. Introduce assembly/router types to collapse MainTabView init surface.
2. Keep tab UX and badges (if any) identical.
3. Preserve pending chat route → Chats tab behavior.
4. Avoid EnvironmentObject god router unless already a project pattern (it isn’t — don’t add).

## Out of scope

- TCA / global app router rewrite
- Changing tab order/product IA
- Slimming every child view (phases 24–29)
- Commit / push / PR unless user asks

## Process

1. Propose assembly shape (short) before coding.
2. Branch: `phase-32-tab-routers-main-tab`.
3. Move wiring out of MainTabView → build → deep link + each tab smoke checklist.

## Acceptance criteria

- [ ] MainTabView init is dramatically simpler
- [ ] Coordinator/composition root still creates dependencies (not Views creating repos)
- [ ] Deep link to chat still works
- [ ] Build passes
