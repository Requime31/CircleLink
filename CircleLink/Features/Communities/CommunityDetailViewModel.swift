import Combine
import Foundation

@MainActor
final class CommunityDetailViewModel: ObservableObject {
    @Published private(set) var communityState: ViewState<Community> = .idle
    @Published private(set) var membersState: ViewState<[User]> = .idle
    @Published private(set) var isMember = false
    @Published private(set) var isMembershipActionInFlight = false
    @Published private(set) var isOpeningGroupChat = false
    @Published private(set) var membershipErrorMessage: String?

    let communityId: String

    private let communityRepository: CommunityRepository
    private let chatRepository: ChatRepository
    private let authRepository: AuthRepository

    init(
        communityId: String,
        communityRepository: CommunityRepository,
        chatRepository: ChatRepository,
        authRepository: AuthRepository
    ) {
        self.communityId = communityId
        self.communityRepository = communityRepository
        self.chatRepository = chatRepository
        self.authRepository = authRepository
    }

    func load() async {
        await loadCommunity()
        await loadMembers()
    }

    func join() async {
        isMembershipActionInFlight = true
        membershipErrorMessage = nil

        do {
            try await communityRepository.join(communityId: communityId)
            isMembershipActionInFlight = false
            await load()
        } catch {
            isMembershipActionInFlight = false
            membershipErrorMessage = error.localizedDescription
        }
    }

    func leave() async {
        isMembershipActionInFlight = true
        membershipErrorMessage = nil

        do {
            // Drop group chat access first — group write rules still require membership.
            try await chatRepository.leaveGroupChat(communityId: communityId)
            try await communityRepository.leave(communityId: communityId)
            isMembershipActionInFlight = false
            await load()
        } catch {
            isMembershipActionInFlight = false
            membershipErrorMessage = error.localizedDescription
        }
    }

    /// Creates or opens the community group chat, then returns `(chatId, title)`.
    ///
    /// Flow:
    /// User tap → View → this method → ChatRepository.createGroupChat
    /// → Firestore chats/{group_id} → callback opens Chat sheet.
    func openGroupChat() async -> (chatId: String, title: String)? {
        guard isMember else {
            membershipErrorMessage = "Join this community to open group chat."
            return nil
        }

        guard let currentUserId = authRepository.currentUser?.id else {
            membershipErrorMessage = "You must be signed in to open group chat."
            return nil
        }

        isOpeningGroupChat = true
        membershipErrorMessage = nil
        defer { isOpeningGroupChat = false }

        do {
            // Always refresh members so new joiners get chatRefs on open.
            let members = try await communityRepository.fetchMembers(communityId: communityId)
            membersState = members.isEmpty ? .empty : .loaded(members)
            updateMembership(from: members)
            syncDisplayedMemberCount(members.count)

            guard members.contains(where: { $0.id == currentUserId }) else {
                membershipErrorMessage = "Only community members can open this group chat."
                isMember = false
                return nil
            }

            let participantIds = members.map(\.id)
            let chatId = try await chatRepository.createGroupChat(
                communityId: communityId,
                participantIds: participantIds
            )

            let title: String
            if case let .loaded(community) = communityState {
                title = community.name
            } else {
                title = "Group Chat"
            }

            return (chatId, title)
        } catch {
            membershipErrorMessage = error.localizedDescription
            return nil
        }
    }

    func resetMembershipActionState() {
        membershipErrorMessage = nil
    }

    private func loadCommunity() async {
        communityState = .loading

        do {
            let communities = try await communityRepository.fetchCommunities()
            if let community = communities.first(where: { $0.id == communityId }) {
                communityState = .loaded(community)
            } else {
                communityState = .error("Community not found.")
            }
        } catch {
            communityState = .error(error.localizedDescription)
        }
    }

    private func loadMembers() async {
        membersState = .loading

        do {
            let members = try await communityRepository.fetchMembers(communityId: communityId)
            membersState = members.isEmpty ? .empty : .loaded(members)
            updateMembership(from: members)
            syncDisplayedMemberCount(members.count)
        } catch {
            membersState = .error(error.localizedDescription)
        }
    }

    private func updateMembership(from members: [User]) {
        guard let currentUserId = authRepository.currentUser?.id else {
            isMember = false
            return
        }
        isMember = members.contains { $0.id == currentUserId }
    }

    private func syncDisplayedMemberCount(_ count: Int) {
        guard case let .loaded(community) = communityState else { return }
        guard community.memberCount != count else { return }
        var updated = community
        updated.memberCount = count
        communityState = .loaded(updated)
    }
}
