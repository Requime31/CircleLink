import SwiftUI
import UIKit

/// Displays avatar from local preview, Firestore base64, or remote URL.
/// Avatar shape is the shared squircle (`CLAvatar` / DESIGN.md), including Chats.
struct AvatarImageView: View {
    let localPreview: UIImage?
    let avatarBase64: String?
    let avatarURL: URL?
    let size: CGFloat

    @State private var remoteImage: UIImage?
    @State private var remoteImageURL: URL?

    var body: some View {
        ZStack {
            avatarContent
                .frame(width: size, height: size)
        }
            .frame(width: size, height: size)
            .clipped()
            .clAvatarClip()
            .accessibilityHidden(true)
            .task(id: loadKey) {
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
        } else if let remoteImage, remoteImageURL == avatarURL {
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
        // A reused SwiftUI row can keep its @State while the model changes.
        // Clear pixels first so a previous person's avatar never flashes.
        remoteImage = nil
        remoteImageURL = nil
        guard localPreview == nil,
              decodeBase64(avatarBase64) == nil,
              let avatarURL else {
            return
        }

        if let cached = ImageLoader.shared.cachedImage(for: avatarURL) {
            remoteImage = cached
            remoteImageURL = avatarURL
            return
        }

        do {
            let loaded = try await ImageLoader.shared.load(from: avatarURL)
            guard Task.isCancelled == false, self.avatarURL == avatarURL else { return }
            remoteImage = loaded
            remoteImageURL = loaded == nil ? nil : avatarURL
        } catch {
            // Keep the source-specific placeholder on failure.
        }
    }

    private var loadKey: AvatarLoadKey {
        AvatarLoadKey(
            localPreviewID: localPreview.map(ObjectIdentifier.init),
            base64: avatarBase64,
            url: avatarURL
        )
    }

    private func decodeBase64(_ value: String?) -> UIImage? {
        guard let value,
              let data = Data(base64Encoded: value) else {
            return nil
        }
        return UIImage(data: data)
    }
}

private struct AvatarLoadKey: Hashable {
    let localPreviewID: ObjectIdentifier?
    let base64: String?
    let url: URL?
}
