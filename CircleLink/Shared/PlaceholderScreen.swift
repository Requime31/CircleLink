import SwiftUI

struct PlaceholderScreen: View {
    let title: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?
    var footnote: String?

    var body: some View {
        CLEmptyState(
            systemImage: systemImage,
            title: title,
            message: footnote ?? "Coming in a future phase",
            actionTitle: actionTitle,
            action: action
        )
        .background(CLColor.canvas)
    }
}
