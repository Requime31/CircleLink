import SwiftUI

/// Shared confirmation surface for every user-blocking entry point.
struct BlockConfirmationView: View {
    let peerName: String
    let isBlocking: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onBlock: () -> Void

    var body: some View {
        CLConfirmationView(
            configuration: CLConfirmationConfiguration(
                title: "Block \(peerName)?",
                message: "They’ll be removed from Connect, likes, and matches. New direct interactions will be blocked.",
                confirmTitle: "Block",
                retryTitle: "Retry block",
                confirmHint: "Removes this person from your Connect lists",
                role: .destructive
            ),
            isPerforming: isBlocking,
            errorMessage: errorMessage,
            onCancel: onCancel,
            onConfirm: onBlock
        ) {
            Image("BlockUserIllustration")
                .resizable()
                .scaledToFit()
        }
    }
}
