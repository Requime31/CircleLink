import SwiftUI
import UIKit

/// Displays avatar from local preview, Firestore base64, or remote URL.
struct AvatarImageView: View {
    let localPreview: UIImage?
    let avatarBase64: String?
    let avatarURL: URL?
    let size: CGFloat

    @State private var remoteImage: UIImage?

    var body: some View {
        Group {
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
            } else if avatarURL != nil {
                ProgressView()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: avatarURL) {
            await loadRemoteImage()
        }
    }

    private func loadRemoteImage() async {
        guard localPreview == nil,
              avatarBase64 == nil,
              let avatarURL else {
            remoteImage = nil
            return
        }

        do {
            remoteImage = try await ImageLoader.shared.load(from: avatarURL)
        } catch {
            remoteImage = nil
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
