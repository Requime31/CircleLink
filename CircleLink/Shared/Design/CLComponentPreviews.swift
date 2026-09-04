#if DEBUG
import SwiftUI

private struct CLComponentCatalog: View {
    @State private var name = "Taylor"
    @State private var password = ""

    var body: some View {
        CLScrollableScreen {
            CLScreenHeader(
                title: "Component Foundation",
                subtitle: "Reusable CircleLink primitives with deliberately long content for adaptive layout testing.",
                leading: .back(action: {}),
                trailing: CLScreenHeaderAction(systemImage: "ellipsis", accessibilityLabel: "More options", action: {})
            )
        } content: {
            CLSectionHeader("Surfaces")
            CLCard(variant: .outlined) { Text("Outlined card") }
            CLCard(variant: .selected) { Text("Selected card") }
            CLCard(variant: .destructive) { Text("Destructive card") }

            CLFormSection("Account", hint: "Fields scale with Dynamic Type.") {
                CLTextField(
                    configuration: .init(title: "Display Name", prompt: "Your name", isRequired: true),
                    text: $name,
                    state: .focused
                )
                CLSecureField(title: "Password", prompt: "Password", text: $password)
                CLCharacterCounter(count: name.count, limit: 30, label: "Display name")
                CLValidationMessage(message: "This is an example validation error.")
            }

            CLFlowLayout {
                CLChip(title: "Design", isSelected: true)
                CLChip(title: "Accessibility")
                CLChip(title: "A deliberately long interest")
            }

            CLStatusBanner(message: "Inline feedback", style: .info, presentation: .inline)
            CLStatusBanner(message: "Compact feedback", style: .error, presentation: .compact)
            CLPersonRow(name: "Morgan Lee", detail: "Online") { CLUnreadBadge(count: 12) }

            CLAsyncButton(
                configuration: .init(title: "Continue", loadingTitle: "Saving…"),
                isDisabled: true,
                action: {}
            )
        }
    }
}

#Preview("Components — Normal") {
    CLComponentCatalog()
}

#Preview("Components — Dark") {
    CLComponentCatalog().preferredColorScheme(.dark)
}

#Preview("Components — Accessibility Type") {
    CLComponentCatalog().environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Components — Narrow") {
    CLComponentCatalog().frame(width: 280)
}

#Preview("State — Loading") {
    CLLoadingState(message: "Loading communities…")
}

#Preview("State — Error") {
    CLErrorState(title: "Couldn’t Load", message: "Check your connection and try again.", retry: {})
}

#Preview("State — Empty") {
    CLEmptyState(systemImage: "person.3", title: "No Communities", message: "Communities you join will appear here.")
}
#endif
