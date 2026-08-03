import SwiftUI

/// Soft sheet wrapper for another user's profile.
///
/// **Public API:**
/// ```swift
/// .sheet(item: $presentedPeer) { item in
///     dependencies.makePeerProfileSheet(
///         userId: item.userId,
///         communityId: item.communityId // pass when known
///     )
/// }
/// ```
/// Composition root builds the ViewModel; the sheet owns it via `@StateObject`.
/// Never auto-opens chat.
struct PeerProfileSheet: View {
    @StateObject private var viewModel: PeerProfileViewModel

    init(viewModel: @autoclosure @escaping () -> PeerProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack {
            PeerProfileView(viewModel: viewModel)
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .modifier(PeerProfileSheetChrome())
        .task {
            await viewModel.load()
        }
    }
}

/// Soft sheet corners when the OS supports them (iOS 16.4+).
private struct PeerProfileSheetChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCornerRadius(CLRadius.xl)
        } else {
            content
        }
    }
}
