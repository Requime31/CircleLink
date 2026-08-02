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

    /// Used by the View to skip opening peer profile for the current user.
    var currentUserId: String? { authRepository.currentUser?.id }

    private let communityRepository: CommunityRepository
    private let authRepository: AuthRepository
    private let leaveCommunity: LeaveCommunityUseCase
    private let openCommunityChat: OpenCommunityChatUseCase

    init(
        communityId: String,
        communityRepository: CommunityRepository,
        authRepository: AuthRepository,
        leaveCommunity: LeaveCommunityUseCase,
        openCommunityChat: OpenCommunityChatUseCase
    ) {
        self.communityId = communityId
        self.communityRepository = communityRepository
        self.authRepository = authRepository
        self.leaveCommunity = leaveCommunity
        self.openCommunityChat = openCommunityChat
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
            try await leaveCommunity.execute(communityId: communityId)
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
    /// User tap → View → this method → OpenCommunityChatUseCase → callback opens Chat sheet.
    func openGroupChat() async -> (chatId: String, title: String)? {
        guard isMember else {
            membershipErrorMessage = "Join this community to open group chat."
            return nil
        }

        isOpeningGroupChat = true
        membershipErrorMessage = nil
        defer { isOpeningGroupChat = false }

        do {
            let output = try await openCommunityChat.execute(communityId: communityId)
            applyMembers(output.members)

            let title: String
            if case let .loaded(community) = communityState {
                title = community.name
            } else {
                title = "Group Chat"
            }

            return (output.chatId, title)
        } catch let OpenCommunityChatUseCaseError.notAMember(members) {
            // Apply refreshed list first (same as pre-UseCase behavior), then clear membership.
            applyMembers(members)
            membershipErrorMessage = OpenCommunityChatUseCaseError.notAMember(members: members)
                .localizedDescription
            return nil
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
            applyMembers(members)
        } catch {
            membersState = .error(error.localizedDescription)
        }
    }

    private func applyMembers(_ members: [User]) {
        membersState = members.isEmpty ? .empty : .loaded(members)
        updateMembership(from: members)
        syncDisplayedMemberCount(members.count)
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
