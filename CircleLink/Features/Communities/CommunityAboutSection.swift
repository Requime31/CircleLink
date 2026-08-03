import SwiftUI

struct CommunityAboutSection: View {
    let community: Community

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            Text("About")
                .font(CLTypography.headline)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            Text(community.description.isEmpty ? "No description yet." : community.description)
                .font(CLTypography.body)
                .foregroundStyle(community.description.isEmpty ? CLColor.inkMuted : CLColor.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
