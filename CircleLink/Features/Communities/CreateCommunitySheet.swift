import SwiftUI

struct CreateCommunitySheet: View {
    @ObservedObject var viewModel: CommunitiesViewModel
    let onDismiss: () -> Void
    @State private var draft = CommunityFormDraft()
    @State private var showsDiscardConfirmation = false

    private var isValid: Bool {
        (try? CommunityContentPolicy.validate(name: draft.name, description: draft.description)) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                CommunityFormContent(draft: $draft, showsInterest: true, isBusy: viewModel.isCreating)
                    .padding(.horizontal, CLSpacing.screenHorizontal)
                    .padding(.vertical, CLSpacing.lg)

                if let error = viewModel.createErrorMessage {
                    Text(error)
                        .font(CLTypography.callout)
                        .foregroundStyle(CLColor.error)
                        .padding(.horizontal, CLSpacing.screenHorizontal)
                        .padding(.bottom, CLSpacing.lg)
                        .accessibilityLabel("Create error: \(error)")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .clCanvasBackground()
            .navigationTitle("New Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: requestDismiss).disabled(viewModel.isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.hasPendingCreatedCommunity ? "Retry Save" : "Create") {
                        Task { await submit() }
                    }
                    .disabled(viewModel.isCreating || !isValid)
                    .accessibilityLabel("Create community")
                }
            }
            .overlay {
                if viewModel.isCreating {
                    ProgressView(viewModel.hasPendingCreatedCommunity ? "Saving cover…" : "Creating…")
                        .padding(CLSpacing.md)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CLRadius.md))
                }
            }
            .interactiveDismissDisabled(draft.isDirty || viewModel.isCreating)
            .confirmationDialog("Discard community draft?", isPresented: $showsDiscardConfirmation) {
                Button("Discard Draft", role: .destructive, action: onDismiss)
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your unsaved changes will be lost.")
            }
            .onAppear { viewModel.clearCreateError() }
        }
    }

    private func requestDismiss() {
        if draft.isDirty || viewModel.hasPendingCreatedCommunity {
            showsDiscardConfirmation = true
        } else {
            onDismiss()
        }
    }

    private func submit() async {
        let didCreate = await viewModel.createCommunity(
            name: draft.name,
            description: draft.description,
            interestTag: draft.interestTag,
            coverImage: draft.selectedCoverData
        )
        if didCreate { onDismiss() }
    }
}
