import SwiftUI

/// Shared confirmation surface for every user-blocking entry point.
struct BlockConfirmationView: View {
    let peerName: String
    let isBlocking: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onBlock: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: CLSpacing.lg) {
                Image("BlockUserIllustration")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 180 : 220)
                    .accessibilityHidden(true)

                VStack(spacing: CLSpacing.sm) {
                    Text("Block \(peerName)?")
                        .font(CLTypography.title)
                        .foregroundStyle(CLColor.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("They’ll be removed from Connect, likes, and matches. New direct interactions will be blocked.")
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage {
                    CLStatusBanner(
                        message: errorMessage,
                        style: .error,
                        accessibilityPrefix: "Block failed"
                    )
                }

                VStack(spacing: CLSpacing.sm) {
                    Button(action: onBlock) {
                        HStack(spacing: CLSpacing.xs) {
                            if isBlocking {
                                ProgressView().tint(.white)
                            }
                            Text(errorMessage == nil ? "Block" : "Retry block")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BlockDestructiveButtonStyle())
                    .disabled(isBlocking)
                    .accessibilityHint("Removes this person from your Connect lists")

                    Button("Cancel", action: onCancel)
                        .buttonStyle(CLSecondaryButtonStyle())
                        .disabled(isBlocking)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.lg)
        }
        .clCanvasBackground()
        .interactiveDismissDisabled(isBlocking)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct BlockDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CLTypography.button)
            .foregroundStyle(.white)
            .frame(minHeight: 52)
            .background(CLColor.error.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
    }
}
