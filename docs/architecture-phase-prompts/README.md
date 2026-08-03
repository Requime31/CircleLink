# Architecture refactor — phase prompts

Self-contained prompts from the CircleLink architecture audit.
Give **one file** to one agent. Do not mix phases in a single chat.

## Core phases (1–11)

| Phase | File | Risk | Depends on |
|------:|------|------|------------|
| 1 | `phase-01-auth-session-restore.md` | Low | — |
| 2 | `phase-02-connect-batch-profiles.md` | Low | — |
| 3 | `phase-03-notification-settings-protocol.md` | Low | — |
| 4 | `phase-04-split-firestore-chat-repository.md` | Medium | — |
| 5 | `phase-05-split-connect-viewmodel.md` | Medium | Better after 2 |
| 6 | `phase-06-extract-chat-viewmodel.md` | Medium | — |
| 7 | `phase-07-targeted-usecases.md` | Medium | Better after 5 |
| 8 | `phase-08-domain-cleanup-community-post-item.md` | Low | — |
| 9 | `phase-09-image-pipeline.md` | Medium | — |
| 10 | `phase-10-coordinator-deeplink-decouple.md` | Medium | Better after 4 |
| 11 | `phase-11-tests-gaps.md` | Low | Re-run after related phases |

## Duplication + concurrency (12–18)

| Phase | File | Focus |
|------:|------|--------|
| 12 | `phase-12-async-auth-profile.md` | Tasks: Auth / AgeGate / Profile |
| 13 | `phase-13-dedupe-chat-list-flows.md` | leaveChat + preview dedupe |
| 14 | `phase-14-async-communities.md` | Tasks: Communities |
| 15 | ~~`phase-15-async-chat.md`~~ **done** | Tasks: Chat / ChatList / ChatInfo |
| 16 | `phase-16-async-connect.md` | Tasks: Connect |
| 17 | `phase-17-auth-cache-thread-safety.md` | Auth cache / Sendable |
| 18 | `phase-18-surface-silent-errors.md` | Silent errors → visible state |

Suggested: **12 → 14 → 13 → 15 → 16 → 17 → 18**

## UI consistency + Domain A (22–23)

| Phase | File | Focus |
|------:|------|--------|
| 22 | `phase-22-cl-empty-state-consistency.md` | `CLEmptyState` reuse (do now) |
| 23 | `phase-23-domain-storage-leakage.md` | Option **A** only — DTO/mapper clarity, no schema change |

## Fat SwiftUI Views — one screen each (24–29)

Priority chosen for coupling / navigation risk first:

| Phase | File | Screen |
|------:|------|--------|
| 24 | `phase-24-slim-connect-view.md` | ConnectView |
| 25 | `phase-25-slim-community-detail-view.md` | CommunityDetailView |
| 26 | `phase-26-slim-chat-list-view.md` | ChatListView |
| 27 | `phase-27-slim-communities-list-view.md` | CommunitiesListView |
| 28 | `phase-28-slim-profile-view.md` | ProfileView |
| 29 | `phase-29-slim-chat-info-view.md` | ChatInfoView |

Prefer **22 before 24–29** so empty/error extraction isn’t redone twice. Prefer **13 before 26**.

## Placement / PeerProfile / MessageCell (19–21)

| Phase | File | Focus |
|------:|------|--------|
| 19 | `phase-19-split-message-cell.md` | Split MessageCell |
| 20 | `phase-20-peer-profile-assembly.md` | PeerProfile DI |
| 21 | `phase-21-misplaced-types.md` | AppleSignInPresenter + DirectChatPeer |

## App navigation / push / Data perf (30–33)

| Phase | File | Focus |
|------:|------|--------|
| 30 | `phase-30-split-push-notification-handler.md` | Split PushNotificationHandler |
| 31 | `phase-31-coordinator-bootstrap-unload.md` | Session/bootstrap out of Coordinator |
| 32 | `phase-32-tab-routers-main-tab.md` | Shrink MainTabView relay |
| 33 | `phase-33-chat-list-batch-reads.md` | Batch chat-list Firestore reads |

Suggested: **3 → 30**, **10 → 31 → 32**, **4 → 33**.

## Recommended big-picture order (if running many agents)

1. Foundations: **1 → 2 → 3 → 17**
2. Data/Chat core: **4 → 6 → 33 → 9**
3. Connect: **5 → 16 → 24**
4. Communities: **7 → 8 → 14 → 25 → 27**
5. Chat list: **13 → 15 → 18 → 26 → 29**
6. Profile/peer: **12 → 20 → 28 → 23**
7. UI polish: **22** (can also run early), **19**
8. App shell: **10 → 30 → 31 → 32**
9. Placement: **21**
10. Tests: **11** continuously / at the end

## Rules for every agent

- Read `ARCHITECTURE.md` first (and `DESIGN.md` for UI phases).
- Create a local git branch before changes (`phase-N-<short-name>`).
- Do not change code outside the phase scope.
- Do not introduce TCA, BaseViewModel, or speculative abstractions.
- After work: explain data flow briefly; run build/tests for touched area.
- Do not commit/push/PR unless the user asks.

## Coverage map

| Concern | Phases |
|---|---|
| God repos / VMs | 4, 5, 6 |
| DI leaks | 1, 3, 20 |
| Logic duplication | 2, 6, 7, 13 |
| Tasks / cancellation | 12, 14, 15, 16 |
| Thread safety | 17 |
| Silent errors | 18 |
| Domain purity | 8, 23 (A) |
| Images | 9 |
| Navigation / deep link | 10, 31, 32 |
| Push god object | 3, 30 |
| Fat SwiftUI views | 24–29 |
| Empty/error UI | 22 |
| UIKit cell | 19 |
| File placement | 21 |
| Chat list N+1 reads | 33 |
| Tests | 11 |
