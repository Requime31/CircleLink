---
title: Chat
type: product
status: current
updated: 2026-09-11
tags: [product, chat, realtime]
---

# Chat

CircleLink supports direct and community group chats. The chat list supports visible and hidden
conversations, pinned ordering, mute state, message search, media browsing, and chat information.
The message thread is UIKit behind a SwiftUI wrapper.

Firestore documents are the single source of truth for message history and live foreground
updates. Snapshot listeners deliver changes while the process is alive; FCM is required for
background or terminated delivery. The repository contains token registration, notification
handling, and post-activity sending functions, but no general chat push sender.

Per-user chat preferences live under `users/{userId}/chatRefs/{chatId}`. The mirrored
`lastMessageAt` must reuse the exact parent Firestore timestamp because rules compare exact values.

## Related decision

- [Firestore realtime source](../decisions/chat/firestore-realtime-source.md)

## Sources

- `CircleLink/Features/Chat/` and `CircleLink/Features/ChatList/`.
- `CircleLink/Data/Firebase/FirestoreChatRepository.swift`.
- `CircleLink/App/PushNotificationHandler.swift`.
