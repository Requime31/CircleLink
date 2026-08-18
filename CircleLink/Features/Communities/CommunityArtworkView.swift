import SwiftUI

/// Community cover with a network image when available and a stable themed fallback for legacy data.
struct CommunityArtworkView: View {
    let community: Community
    var cornerRadius: CGFloat = CLRadius.md

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let url = community.coverImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty:
                            fallback.overlay { ProgressView().tint(CLColor.primary) }
                        case .failure:
                            fallback
                        @unknown default:
                            fallback
                        }
                    }
                } else {
                    fallback
                }
            }
            // Constrain every remote image to the size proposed by the caller.
            // This prevents unusually wide or tall covers from changing card layout.
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CLColor.hairline, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        LinearGradient(
            colors: fallbackColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: fallbackSymbol)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(CLColor.inkSecondary.opacity(0.7))
        }
    }

    private var fallbackColors: [Color] {
        let palettes: [[Color]] = [
            [CLColor.accentSoft, CLColor.primarySoft],
            [CLColor.tintMint, CLColor.surface],
            [CLColor.tintCream, CLColor.hairlineStrong.opacity(0.65)],
            [CLColor.tintRose, CLColor.accentSoft]
        ]
        return palettes[stableIndex % palettes.count]
    }

    private var fallbackSymbol: String {
        let tag = community.interestTag.lowercased()
        if tag.contains("photo") { return "camera" }
        if tag.contains("music") { return "music.note" }
        if tag.contains("book") || tag.contains("writ") { return "book.closed" }
        if tag.contains("plant") || tag.contains("nature") { return "leaf" }
        if tag.contains("art") || tag.contains("ceramic") { return "paintpalette" }
        if tag.contains("tech") { return "laptopcomputer" }
        return "person.3"
    }

    private var stableIndex: Int {
        community.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }
}
