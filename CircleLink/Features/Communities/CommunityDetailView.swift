import SwiftUI

struct CommunityDetailView: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    let onOpenGroupChat: (String) -> Void

    var body: some View {
        Group {
            switch viewModel.communityState {
            case .idle, .loading:
                ProgressView("Loading community…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .error(message):
                errorState(message: message)
            case .empty:
                errorState(message: "Community not found.")
            case let .loaded(community):
                detailContent(community: community)
            }
        }
        .navigationTitle(viewModel.communityState.loadedValue?.name ?? "Community")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func detailContent(community: Community) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection(community: community)
                membershipSection
                membersSection
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func headerSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(community.interestTag)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Text(community.description)
                .font(.body)
                .foregroundStyle(.secondary)

            Text(memberCountLabel(for: community.memberCount))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var membershipSection: some View {
        VStack(spacing: 12) {
            if viewModel.isMember {
                Button {
                    Task { await viewModel.leave() }
                } label: {
                    membershipButtonLabel(title: "Leave Community", isLoading: viewModel.isMembershipActionInFlight)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Leave community")

                Button {
                    onOpenGroupChat(viewModel.communityId)
                } label: {
                    Text("Open Group Chat")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.22, blue: 0.36))
                .accessibilityLabel("Open group chat")
            } else {
                Button {
                    Task { await viewModel.join() }
                } label: {
                    membershipButtonLabel(title: "Join Community", isLoading: viewModel.isMembershipActionInFlight)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.22, blue: 0.36))
                .disabled(viewModel.isMembershipActionInFlight)
                .accessibilityLabel("Join community")
            }

            if let membershipErrorMessage = viewModel.membershipErrorMessage {
                Text(membershipErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Membership error: \(membershipErrorMessage)")
            }
        }
    }

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.headline)

            switch viewModel.membersState {
            case .idle, .loading:
                ProgressView("Loading members…")
                    .frame(maxWidth: .infinity, alignment: .center)
            case .empty:
                Text("No members yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case let .error(message):
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Members error: \(message)")
            case let .loaded(members):
                LazyVStack(spacing: 12) {
                    ForEach(members) { member in
                        MemberRowView(user: member)
                    }
                }
            }
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .accessibilityLabel("Retry loading community")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func membershipButtonLabel(title: String, isLoading: Bool) -> some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
    }

    private func memberCountLabel(for count: Int) -> String {
        count == 1 ? "1 member" : "\(count) members"
    }
}

private struct MemberRowView: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            AvatarImageView(
                localPreview: nil,
                avatarBase64: user.avatarBase64,
                avatarURL: user.avatarURL,
                size: 44
            )

            Text(user.displayName)
                .font(.subheadline)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Member: \(user.displayName)")
    }
}

private extension ViewState {
    var loadedValue: T? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }
}
