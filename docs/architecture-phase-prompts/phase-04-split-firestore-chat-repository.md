# Phase 4 — Split FirestoreChatRepository (internal), keep ChatRepository facade

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Break the god object `FirestoreChatRepository` (~617 LOC) into smaller internal collaborators, while **keeping** the public `ChatRepository` protocol as the single facade for ViewModels.

## Why

One Data type currently owns: chat list, hidden/mute, message history, send + image upload, realtime listener, direct/group creation, leave, access repair, summary building. Hard to read, test, and change safely. ViewModels should not need a new public API surface for this phase.

## Context

- Fat type: `CircleLink/Data/Firebase/FirestoreChatRepository.swift`
- Protocol (keep stable): `CircleLink/Domain/Repositories/ChatRepository.swift`
- Related mappers: `FirestoreChatMapper.swift`, image storage via `ChatImageStorage`
- Consumers: Chat / ChatList / Communities / Connect ViewModels via `AppDependencies`
- Docs: `ARCHITECTURE.md` (realtime rules, listener lifecycle)

## Suggested internal split (adjust if better after reading code)

- List / summaries store
- Messages store (history + send)
- Membership / direct+group create+leave store
- Realtime source (`observeLiveMessages`)

`FirestoreChatRepository` can become a thin facade that forwards to these types.

## Scope

1. Read the full repository + protocol before cutting.
2. Extract collaborators under `Data/Firebase/` (or a subfolder) without changing Domain protocol signatures unless a bug forces it.
3. Preserve listener cancellation: registration removed when `AsyncStream` terminates.
4. Avoid behavior changes; this is a structural refactor.
5. Keep DI wiring in `AppDependencies` compiling (still inject one `ChatRepository`).

## Out of scope

- Changing SwiftUI/UIKit chat UI
- Splitting `ChatViewModel` (Phase 6)
- Performance rewrite of N+1 summary fetches (mention as follow-up if you see it; optional small win only if safe)
- New UseCase layer
- Commit / push / PR unless user asks

## Process

1. Propose file/type boundaries + ownership first.
2. Branch: `phase-4-split-firestore-chat-repository`.
3. Move code in small steps; keep app building after each meaningful cut if possible.
4. Run Chat-related ViewModel tests; manually note any behavior risk.
5. Code review checklist: Sendable, listener remove, MainActor boundaries, no Firebase in Domain.

## Acceptance criteria

- [ ] `FirestoreChatRepository.swift` is no longer a single mega-file of mixed concerns (or is a thin facade)
- [ ] `ChatRepository` protocol unchanged (or only additive/compatible)
- [ ] Realtime listener still tears down on cancel
- [ ] Chat send / list / open group still compile and existing Chat tests pass

## Data flow (unchanged externally)

ViewModel → `ChatRepository` → facade → internal store(s) → Firestore / Supabase image storage → domain models → ViewModel state
