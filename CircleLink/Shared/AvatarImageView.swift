import SwiftUI
import UIKit

/// Displays avatar from local preview, Firestore base64, or remote URL.
/// Shape: squircle (`CLAvatar` / DESIGN.md) — not a circle.
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
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius(for: size), style: .continuous))
        .accessibilityHidden(true)
        .task(id: avatarURL) {
            await loadRemoteImage()
        }
    }

    /// Keeps squircles readable at tiny sizes (near-round) and premium at large sizes.
    private static func cornerRadius(for size: CGFloat) -> CGFloat {
        min(CLAvatar.cornerRadius, size * 0.28)
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
