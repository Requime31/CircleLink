import SwiftUI
import UIKit

/// Full-bleed profile photo for Connect hero cards (not the squircle avatar).
/// Uses GeometryReader so `scaledToFill` cannot blow up the parent layout.
struct ProfileHeroImageView: View {
    let avatarBase64: String?
    let avatarURL: URL?
    var onReadinessChange: ((Bool) -> Void)? = nil

    private struct Request: Equatable {
        let base64: String?
        let url: URL?
    }
    private var request: Request { Request(base64: avatarBase64, url: avatarURL) }
    @State private var settledRequest: Request?

    @State private var remoteImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            imageContent
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .task(id: request) {
            await loadRemoteImage()
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let base64Image = decodeBase64(avatarBase64) {
            Image(uiImage: base64Image)
                .resizable()
                .scaledToFill()
        } else if settledRequest == request, let remoteImage {
            Image(uiImage: remoteImage)
                .resizable()
                .scaledToFill()
        } else if let avatarURL, let cached = ImageLoader.shared.cachedImage(for: avatarURL) {
            Image(uiImage: cached)
                .resizable()
                .scaledToFill()
        } else if avatarURL != nil, settledRequest != request {
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
        let expected = request
        if decodeBase64(avatarBase64) != nil || avatarURL == nil {
            onReadinessChange?(true)
            return
        }
        guard let avatarURL else { return }
        if settledRequest == expected {
            onReadinessChange?(true)
            return
        }
        if let cached = ImageLoader.shared.cachedImage(for: avatarURL) {
            remoteImage = cached
            settledRequest = expected
            onReadinessChange?(true)
            return
        }
        onReadinessChange?(false)
        do {
            let image = try await ImageLoader.shared.load(from: avatarURL)
            try Task.checkCancellation()
            remoteImage = image
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            remoteImage = nil
        }
        guard !Task.isCancelled else { return }
        // Failed/invalid images settle to a static placeholder, never an endless spinner.
        settledRequest = expected
        onReadinessChange?(true)
    }

    private func decodeBase64(_ value: String?) -> UIImage? {
        guard let value, !value.isEmpty,
              let data = Data(base64Encoded: value) else {
            return nil
        }
        return UIImage(data: data)
    }
}
