import SwiftUI

struct EditCommunitySheet: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    let community: Community
    let onDismiss: () -> Void
    @State private var draft: CommunityFormDraft
    @State private var showsDiscardConfirmation = false

    init(viewModel: CommunityDetailViewModel, community: Community, onDismiss: @escaping () -> Void) {
        self.viewModel = viewModel
        self.community = community
        self.onDismiss = onDismiss
        _draft = State(initialValue: CommunityFormDraft(community: community))
    }

    private var isValid: Bool {
        (try? CommunityContentPolicy.validate(name: draft.name, description: draft.description)) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                CommunityFormContent(draft: $draft, showsInterest: false, isBusy: viewModel.isSavingCommunity)
                    .padding(.horizontal, CLSpacing.screenHorizontal).padding(.vertical, CLSpacing.lg)
                if let error = viewModel.communityEditErrorMessage {
                    Text(error).font(CLTypography.callout).foregroundStyle(CLColor.error)
                        .padding(.horizontal, CLSpacing.screenHorizontal).padding(.bottom, CLSpacing.lg)
                        .accessibilityLabel("Save error: \(error)")
                }
            }
            .scrollDismissesKeyboard(.interactively).clCanvasBackground()
            .navigationTitle("Edit Community").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: requestDismiss).disabled(viewModel.isSavingCommunity)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await submit() } }
                        .disabled(viewModel.isSavingCommunity || !isValid || !draft.isDirty)
                }
            }
            .overlay {
                if viewModel.isSavingCommunity {
                    ProgressView("Saving…").padding(CLSpacing.md)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CLRadius.md))
                }
            }
            .interactiveDismissDisabled(draft.isDirty || viewModel.isSavingCommunity)
            .confirmationDialog("Discard community changes?", isPresented: $showsDiscardConfirmation) {
                Button("Discard Changes", role: .destructive, action: onDismiss)
                Button("Keep Editing", role: .cancel) {}
            } message: { Text("Your unsaved changes will be lost.") }
            .onAppear { viewModel.clearCommunityEditError() }
        }
    }

    private func requestDismiss() {
        if draft.isDirty { showsDiscardConfirmation = true } else { onDismiss() }
    }

    private func submit() async {
        let didSave = await viewModel.saveCommunity(
            name: draft.name, description: draft.description, coverEdit: draft.coverEdit
        )
        if didSave { onDismiss() }
    }
}
