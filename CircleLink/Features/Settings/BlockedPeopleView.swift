import SwiftUI

struct BlockedPeopleView: View {
    @StateObject private var viewModel: BlockedPeopleViewModel
    @State private var confirmationTarget: BlockedPersonRow?

    init(viewModel: @autoclosure @escaping () -> BlockedPeopleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                CLLoadingState(message: "Loading blocked people…")
            case .empty:
                emptyState
            case let .error(message):
                CLEmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn’t load blocked people",
                    message: message,
                    actionTitle: "Retry",
                    actionAccessibilityLabel: "Retry loading blocked people"
                ) {
                    Task { await viewModel.load() }
                }
            case let .loaded(rows):
                peopleList(rows)
            }
        }
        .clCanvasBackground()
        .navigationTitle("Blocked People")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { confirmationTarget != nil },
                set: { if !$0 { confirmationTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = confirmationTarget {
                Button("Unblock") {
                    confirmationTarget = nil
                    Task { _ = await viewModel.unblock(target) }
                }
            }
            Button("Cancel", role: .cancel) { confirmationTarget = nil }
        } message: {
            Text("They may appear in Connect again after the next refresh.")
        }
        .alert(
            "Couldn’t unblock",
            isPresented: Binding(
                get: { viewModel.actionErrorMessage != nil },
                set: { if !$0 { viewModel.clearActionError() } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.clearActionError() }
        } message: {
            Text(viewModel.actionErrorMessage ?? "Please try again.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: CLSpacing.lg) {
            Image("BlockedPeopleEmptyIllustration")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240)
                .accessibilityHidden(true)
            Text("No blocked people")
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text("People you block will appear here.")
                .font(CLTypography.body)
                .foregroundStyle(CLColor.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(CLSpacing.screenHorizontal)
    }

    private func peopleList(_ rows: [BlockedPersonRow]) -> some View {
        List(rows) { row in
            HStack(spacing: CLSpacing.sm) {
                AvatarImageView(
                    localPreview: nil,
                    avatarBase64: row.avatarBase64,
                    avatarURL: row.avatarURL,
                    size: 52
                )
                .accessibilityHidden(true)

                Text(row.displayName)
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Unblock") {
                    confirmationTarget = row
                }
                .buttonStyle(.borderless)
                .font(CLTypography.button)
                .foregroundStyle(CLColor.primaryPressed)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(viewModel.unblockingIDs.contains(row.id))
                .accessibilityLabel("Unblock \(row.displayName)")
            }
            .padding(.vertical, CLSpacing.xxs)
            .listRowBackground(CLColor.surface)
            .accessibilityElement(children: .contain)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.load() }
    }

    private var confirmationTitle: String {
        "Unblock \(confirmationTarget?.displayName ?? "this person")?"
    }
}
