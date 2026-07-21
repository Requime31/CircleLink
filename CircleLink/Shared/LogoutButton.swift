import SwiftUI

struct LogoutButton: View {
    let action: () -> Void

    var body: some View {
        Button("Log Out", role: .destructive) {
            action()
        }
        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        .accessibilityLabel("Log out of your account")
    }
}
