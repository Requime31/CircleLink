import SwiftUI

/// SwiftUI chrome around the UIKit chat screen (close + report/block for direct chats).
struct ChatSheetView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onClose: () -> Void

    @State private var showReportReasons = false
    @State private var showBlockConfirm = false

    var body: some View {
        ChatViewControllerWrapper(viewModel: viewModel)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar {
                if viewModel.canModeratePeer {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Report…") {
                                showReportReasons = true
                            }
                            Button("Block…", role: .destructive) {
                                showBlockConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Chat options")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .accessibilityLabel("Close chat")
                }
            }
            .confirmationDialog(
                "Why are you reporting this user?",
                isPresented: $showReportReasons,
                titleVisibility: .visible
            ) {
                ForEach(ReportReason.allCases, id: \.self) { reason in
                    Button(reason.title) {
                        Task { await viewModel.reportPeer(reason: reason) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Block this user? They won’t appear in Connect for you.",
                isPresented: $showBlockConfirm,
                titleVisibility: .visible
            ) {
                Button("Block", role: .destructive) {
                    Task { await viewModel.blockPeer() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(
                "Report sent",
                isPresented: Binding(
                    get: { viewModel.moderationMessage != nil },
                    set: { if !$0 { viewModel.clearModerationFeedback() } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.clearModerationFeedback()
                }
            } message: {
                Text(viewModel.moderationMessage ?? "")
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.moderationErrorMessage != nil },
                    set: { if !$0 { viewModel.clearModerationFeedback() } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.clearModerationFeedback()
                }
            } message: {
                Text(viewModel.moderationErrorMessage ?? "")
            }
    }
}
