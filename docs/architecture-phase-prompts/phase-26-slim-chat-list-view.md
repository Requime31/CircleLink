# Phase 26 — Slim ChatListView (one screen)

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Thin `ChatListView` by extracting row chrome, empty/error host, navigation destinations, and pending-route handling into smaller pieces. Behavior unchanged.

## Why

~290 LOC with search, previews, mute/hide, navigation to chat/info, deep-link `pendingChatRoute` consumption — high coupling surface.

## Context

- `Features/ChatList/ChatListView.swift`
- `ChatListRowView.swift`, `HiddenChatsView.swift`, routes
- `ChatsViewModel`
- Prefer after phase 13 (preview/leave dedupe) and phase 22 (empty states); integrate with what’s there

## Scope

1. Extract destination builders / pending-route applicator helpers if they bloat the body.
2. Keep deep-link / `pendingChatRoute` behavior identical (phase 10 may have changed source of metadata — don’t regress).
3. Don’t re-implement preview cache in the View if phase 13 moved it to the VM.

## Out of scope

- HiddenChats full rewrite (small extract OK if shared)
- ChatViewModel / UIKit chat
- Tab router introduction (phase 32)
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-26-slim-chat-list-view`.
2. Extract → build → checklist: open chat, chat info, hide/mute, pending route open.

## Acceptance criteria

- [ ] ChatListView easier to read
- [ ] Pending deep link still pushes the right chat
- [ ] Build passes
