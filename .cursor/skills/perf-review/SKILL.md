---
name: perf-review
description: Performance review of the current CircleLink diff. Use when the user asks for a performance review, perf pass, or to check main-thread / listener / fetch issues.
---

# Performance review

Review **the current diff** (and nearby call sites), not the whole app. Do not write a general iOS performance essay.

Canonical realtime rules: [ARCHITECTURE.md](ARCHITECTURE.md).

## Checklist

1. **Main thread** — heavy work (image compress, mapping large lists, JSON) must not sit extra on `@MainActor` beyond UI updates. ViewModels are `@MainActor`; keep them thin.
2. **Listeners** — every `addSnapshotListener` has a matching remove when the `AsyncStream` ends / the screen disappears. No new listeners in Views.
3. **Chat path** — screens use `ChatRepository.observeLiveMessages`. No Firestore listeners in UI.
4. **Over-fetch** — no full collection read where a query / pagination already exists (`fetchMessages`). No fetch on every SwiftUI re-render (`onAppear` / `task` must be idempotent).
5. **Images** — chat uploads go through `ImageCompressor`; do not upload originals. Avatars stay compressed base64 in Firestore, not a new Storage pipeline unless asked.
6. **Lists** — Connect / chat list / communities: do not load full chat history to show a row. Prefer existing summary / preview fields.
7. **Allocations** — avoid copying large arrays on each listener event; dedupe by id (chat already uses `id` + `clientMessageId`).

## Report shape

For each issue: **where** (file + symbol), **what happens**, **why it costs**, **what to change**. If nothing fails the checklist, say so in a few lines.

## Do not

- require Instruments traces unless the user asks
- suggest bringing back iOS WebSocket for “faster chat”
- suggest Cloud Functions or a new backend for perf
