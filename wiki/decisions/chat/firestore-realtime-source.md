---
id: adr-chat-firestore-realtime-source
title: Firestore as the Chat Realtime Source
type: decision
status: implemented
date: 2026-09-01
tags: [chat, firestore, realtime]
sources:
  - git:0b8696f
  - legacy:ARCHITECTURE.md
---

# Firestore as the Chat Realtime Source

## Context

Earlier history included a separate WebSocket path alongside Firestore-first persistence. Two live
delivery paths complicate ordering, deduplication, lifecycle, and failure handling.

## Decision

Firestore message documents are the only chat source of truth. `addSnapshotListener` feeds
foreground changes through repository-owned async streams, historical reads provide pagination,
and FCM is responsible for delivery when the process is backgrounded or terminated. The legacy
WebSocket implementation is historical only.

## Consequences

Message consistency and lifecycle become simpler. Foreground listeners still do not replace a
server-side chat push sender, which remains outside the current repository.

## Sources

- [Chat living page](../../product/chat.md)
- `CircleLink/Data/Firebase/FirestoreChatRepository.swift`.
- Integration commit `0b8696f` and legacy architecture documentation.
