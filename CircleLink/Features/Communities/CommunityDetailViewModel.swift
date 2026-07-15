import Combine
import Foundation

@MainActor
final class CommunityDetailViewModel: ObservableObject {
    @Published private(set) var communityState: ViewState<Community> = .idle
    @Published private(set) var membersState: ViewState<[User]> = .idle
    @Published private(set) var isMember = false
    @Published private(set) var isMembershipActionInFlight = false
    @Published private(set) var membershipErrorMessage: String?

    let communityId: String

    private let communityRepository: CommunityRepository
    private let authRepository: AuthRepository

    init(
        communityId: String,
        communityRepository: CommunityRepository,
        authRepository: AuthRepository
    ) {
        self.communityId = communityId
        self.communityRepository = communityRepository
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
            try await communityRepository.leave(communityId: communityId)
            isMembershipActionInFlight = false
            await load()
        } catch {
            isMembershipActionInFlight = false
            membershipErrorMessage = error.localizedDescription
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
}
