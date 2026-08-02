# Phase 33 — Chat list: fix serial N+1 summary reads

You are a senior iOS engineer working in the CircleLink repo.

## Goal

Speed up / simplify `FirestoreChatRepository` chat-list loading by removing serial per-ref Firestore reads where batching is possible. Keep `ChatRepository` API stable unless a tiny additive change is required.

## Why

List load roughly does: for each chat ref → `makeSummary` → fetch chat doc (+ maybe user doc) sequentially. With many chats this is 100–200 round-trips.

Phase 4 may have split the repository internally — apply this optimization in the list/summary collaborator.

## Context

- `Data/Firebase/FirestoreChatRepository.swift` (+ any stores from phase 4)
- `Domain/Repositories/ChatRepository.swift`
- Mappers: `FirestoreChatMapper.swift`, user mapper
- `ChatsViewModel` consumer
- Also check `FirestoreConnectionRepository` candidate loops **only if** the same PR stays small; default = chat list only

## Scope

1. Measure/read current list path; document current read pattern in the summary.
2. Batch where Firestore allows (e.g. collect ids → fewer gets / concurrent limited fetches with `withThrowingTaskGroup`, or cached user map via `fetchProfiles`).
3. Preserve ordering, muted/hidden organization, and error behavior as much as possible.
4. No UI changes.
5. Add a comment explaining the batching strategy and failure partial-results policy.

## Out of scope

- Changing realtime message listeners
- Rewriting send message
- Connect N+1 (phase 2)
- Full Firebase query model redesign
- Commit / push / PR unless user asks

## Process

1. Branch: `phase-33-chat-list-batch-reads`.
2. Propose batching approach first (short).
3. Implement in Data layer → build → Chat list tests if any; reason about partial failures.

## Acceptance criteria

- [ ] Chat list load no longer does naive serial one-by-one summary building for every ref (or documents why a specific remaining serial step is required)
- [ ] `ChatRepository` consumers unchanged
- [ ] Hidden/muted/visible behavior preserved
- [ ] Build passes

## Data flow

ChatsViewModel.load → ChatRepository.fetch… → batched Firestore reads → `[ChatSummary]` / organized chats → UI
