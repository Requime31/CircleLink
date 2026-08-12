import SwiftUI
import UIKit

/// Displays avatar from local preview, Firestore base64, or remote URL.
/// Default shape: squircle (`CLAvatar` / DESIGN.md). Pass `clip: .chat` for Chats (circle).
struct AvatarImageView: View {
    let localPreview: UIImage?
    let avatarBase64: String?
    let avatarURL: URL?
    let size: CGFloat
    var clip: CLAvatarClip = .squircle

    @State private var remoteImage: UIImage?

    var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .modifier(AvatarClipModifier(clip: clip, size: size))
            .accessibilityHidden(true)
            .task(id: avatarURL) {
                await loadRemoteImage()
            }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let localPreview {
            Image(uiImage: localPreview)
                .resizable()
                .scaledToFill()
        } else if let base64Image = decodeBase64(avatarBase64) {
            Image(uiImage: base64Image)
                .resizable()
                .scaledToFill()
        } else if let remoteImage {
            Image(uiImage: remoteImage)
                .resizable()
                .scaledToFill()
        } else if let avatarURL, let cached = ImageLoader.shared.cachedImage(for: avatarURL) {
            Image(uiImage: cached)
                .resizable()
                .scaledToFill()
        } else if avatarURL != nil {
            ZStack {
                CLColor.surfaceSoft
                ProgressView()
                    .tint(CLColor.primary)
            }
        } else {
            ZStack {
                CLColor.surfaceSoft
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(CLColor.inkSecondary)
            }
        }
    }

    private func loadRemoteImage() async {
        guard localPreview == nil,
              avatarBase64 == nil || avatarBase64?.isEmpty == true,
              let avatarURL else {
            return
        }

        // Keep current pixels if we already have them (or cache hit).
        if remoteImage != nil { return }
        if let cached = ImageLoader.shared.cachedImage(for: avatarURL) {
            remoteImage = cached
            return
        }

        do {
            remoteImage = try await ImageLoader.shared.load(from: avatarURL)
        } catch {
            // Keep placeholder; don't clear a good image on transient failure.
        }
    }

    private func decodeBase64(_ value: String?) -> UIImage? {
        guard let value,
              let data = Data(base64Encoded: value) else {
            return nil
        }
        return UIImage(data: data)
    }
}

private struct AvatarClipModifier: ViewModifier {
    let clip: CLAvatarClip
    let size: CGFloat

    func body(content: Content) -> some View {
        switch clip {
        case .squircle:
            content.clipShape(
                RoundedRectangle(cornerRadius: Self.cornerRadius(for: size), style: .continuous)
            )
        case .chat:
            content.clipShape(Circle())
        }
    }

    private static func cornerRadius(for size: CGFloat) -> CGFloat {
        min(CLAvatar.cornerRadius, size * 0.28)
    }
}
