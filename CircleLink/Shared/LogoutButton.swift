import SwiftUI

struct LogoutButton: View {
    let action: () -> Void

    var body: some View {
        Button("Log Out", role: .destructive) {
            action()
        }
        .accessibilityLabel("Log out of your account")
    }
}
