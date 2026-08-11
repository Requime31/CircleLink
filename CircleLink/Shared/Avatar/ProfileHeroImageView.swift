import SwiftUI
import UIKit

/// Full-bleed profile photo for Connect hero cards (not the squircle avatar).
/// Uses GeometryReader so `scaledToFill` cannot blow up the parent layout.
struct ProfileHeroImageView: View {
    let avatarBase64: String?
    let avatarURL: URL?

    @State private var remoteImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            imageContent
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .task(id: avatarURL?.absoluteString) {
            await loadRemoteImage()
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let base64Image = decodeBase64(avatarBase64) {
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
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(CLColor.inkSecondary)
            }
        }
    }

    private func loadRemoteImage() async {
        guard avatarBase64 == nil || avatarBase64?.isEmpty == true,
              let avatarURL else {
            return
        }
        if remoteImage != nil { return }
        if let cached = ImageLoader.shared.cachedImage(for: avatarURL) {
            remoteImage = cached
            return
        }
        do {
            remoteImage = try await ImageLoader.shared.load(from: avatarURL)
        } catch {
            // Keep placeholder on failure.
        }
    }

    private func decodeBase64(_ value: String?) -> UIImage? {
        guard let value, !value.isEmpty,
              let data = Data(base64Encoded: value) else {
            return nil
        }
        return UIImage(data: data)
    }
}
