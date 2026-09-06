# UI Components Adoption Checklist

Status: **complete** on `codex/ui-components-adoption`.

Foundation: `codex/ui-components-foundation` (`b50de64`). The adoption pass introduced shared
primitives under `Shared/Design` and feature-specific components under each feature's
`Components` directory. Contextual guides and spotlight remain out of scope.

## App and Auth

- [x] `App/LoadingView.swift` — audited; branded launch animation remains app-specific
- [x] `Features/Auth/AuthView.swift`
- [x] `Features/AgeGate/AgeGateView.swift`
- [x] Product Onboarding — not present in the selected pre-guide base
- [x] Notification explanation — not present in the selected pre-guide base
- [x] Coordinator-level SwiftUI overlays in `AppCoordinator.swift`

## Profile

- [x] `ProfileSetupView.swift`
- [x] `ProfileEditView.swift`
- [x] `ProfileFormFields.swift`
- [x] `ProfileView.swift`
- [x] `PeerProfileView.swift`
- [x] `PeerProfileSheet.swift` — audited; sheet detents/chrome remain feature-specific
- [x] `ComposeProfilePostSheet.swift`
- [x] `ProfilePostsListView.swift`

## Communities

- [x] `CommunitiesListView.swift`
- [x] `CommunityDiscoveryComponents.swift`
- [x] `CommunityDetailView.swift`
- [x] `CreateCommunitySheet.swift`
- [x] `EditCommunitySheet.swift`
- [x] `CommunityFormContent.swift`
- [x] `CommunityComposePostSheet.swift`
- [x] `CommunityPostCard.swift`
- [x] Community gallery and member rows in `CommunityDetailView.swift`

## Connect

- [x] `ConnectView.swift` — audited; swipe feedback and deck controls remain feature-specific
- [x] `ConnectDiscoverDeckView.swift`
- [x] `LikedYouView.swift`
- [x] `MatchesView.swift`
- [x] `OutgoingLikesView.swift`

## Chats

- [x] `ChatListView.swift`
- [x] `HiddenChatsView.swift`
- [x] `ChatMessageSearchView.swift`
- [x] `ChatInfoView.swift`
- [x] `ChatParticipantsView.swift`
- [x] `ChatMediaGalleryView.swift`
- [x] `ConversationPeekPreview.swift`
- [x] `ChatThreadView.swift` SwiftUI wrapper — audited
- [x] UIKit appearance audit (`ChatAppearance`, `InputBarView`, `MessageCell`) — kept outside SwiftUI library

## Settings and Legal

- [x] `SettingsView.swift`
- [x] App Guide entry — not present in the selected pre-guide base
- [x] `FAQView.swift` — audited; native list content needs no wrapper
- [x] `SupportView.swift` — audited; mail composer bridge remains feature-specific
- [x] `BlockedPeopleView.swift`
- [x] `AccountRecoveryView.swift`
- [x] `AccountDeletionView.swift`
- [x] `LegalDocumentView.swift`

## Verification

- [x] Remove unused local helpers and modifiers
- [x] Re-run duplicate-pattern search and classify remaining matches
- [x] Add/update previews for adaptive and state variants (component catalog)
- [x] Add regression tests for reusable presentation logic
- [x] Build without new warnings
- [x] Run relevant tests
- [x] Run `git diff --check`
