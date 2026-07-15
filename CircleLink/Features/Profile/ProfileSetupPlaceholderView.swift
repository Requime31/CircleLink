import SwiftUI

struct ProfileSetupPlaceholderView: View {
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            PlaceholderScreen(
                title: "Profile Setup",
                systemImage: "person.crop.circle.badge.plus"
            )

            Text("Complete your profile in Phase 3.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LogoutButton(action: onSignOut)
                .padding(.horizontal, 24)
        }
        .navigationTitle("Profile Setup")
    }
}
