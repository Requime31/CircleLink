# Phase 9 — Image pipeline: one compress path, off MainActor, less hidden globals

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Fix image handling smells: double compression, MainActor/UI-thread heavy work, and `ImageCompressor` living under `Data/Firebase` while used by UI. Optionally reduce reliance on `ImageLoader.shared` where you already touch call sites.

## Why

Audit findings:

1. Chat UIKit compresses before send; `FirestoreChatRepository.sendMessage` may compress again.
2. Profile / chat compression often runs in `@MainActor` contexts → UI hitch risk.
3. `ImageCompressor` is generic media util misplaced under Firebase.
4. `ImageLoader.shared` is a hidden networking/cache dependency in Views/cells.

## Context

- `CircleLink/Data/Firebase/ImageCompressor.swift`
- `CircleLink/Chat/ChatViewController.swift` (picker → compress → send)
- Chat repository send path (image upload)
- `CircleLink/Features/Profile/ProfileViewModel.swift` (`UIImage` preview + compress)
- `CircleLink/Shared/ImageLoader.swift`, `AvatarImageView`, `CommunityPostCardView`, `MessageCell`
- Supabase storages for chat/community images
- Docs: `ARCHITECTURE.md`

## Scope (keep focused)

Must do:

1. Define a single compression responsibility: either UI sends already-final bytes and repository does **not** recompress, **or** repository always compresses and UI only passes raw — pick one, document in a short comment/`ARCHITECTURE.md` note.
2. Move compression off the main actor (e.g. background work then hop back for state updates).
3. Relocate `ImageCompressor` out of `Data/Firebase/` into a neutral place (e.g. `Shared/` or `Data/Media/`).

Nice-to-have if small:

4. Introduce a simple `ImageLoading` protocol and inject/default to current loader for 1–2 call sites you already edit — don’t rewrite every cell in the app unless easy.

## Out of scope

- Replacing Supabase/Firebase storage providers
- Full Nuke/Kingfisher migration
- Redesigning chat bubble layout
- Commit / push / PR unless user asks

## Process

1. Trace send-image path end-to-end; propose the single-compress rule first.
2. Branch: `phase-9-image-pipeline`.
3. Implement → build → smoke-check Profile avatar save + chat image send mentally/tests if any.
4. Explicit performance/async review: no heavy encode on MainActor; cancellation if task-based.

## Acceptance criteria

- [ ] No double-compress on chat send path
- [ ] Compression not blocking MainActor
- [ ] `ImageCompressor` not under `Data/Firebase/`
- [ ] Existing send/upload behavior preserved (size/quality policy documented)
- [ ] Build passes

## Data flow (chat image) after change

User picks image → ChatViewController (decode if needed) → compress **once** off-main → ChatViewModel.send(imageData:) → ChatRepository → ChatImageStorage upload + Firestore message → status update → UI
