import SwiftUI

struct ProfilePlaceholderView: View {
    @ObservedObject var viewModel: ProfileViewModel
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            PlaceholderScreen(
                title: "Profile",
                systemImage: "person.circle"
            )

            LogoutButton {
                if viewModel.signOut() {
                    onSignOut()
                }
            }
            .padding(.horizontal, 24)

            if case let .error(message) = viewModel.state {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Error: \(message)")
            }
        }
    }
}
