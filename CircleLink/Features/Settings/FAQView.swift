import SwiftUI

enum FAQCategory: String, CaseIterable, Sendable {
    case account = "Account"
    case connect = "Connect"
    case communities = "Communities"
    case chats = "Chats"
    case safety = "Safety"
    case preferences = "Preferences"
    case privacy = "Privacy"
}

struct FAQItem: Identifiable, Equatable, Sendable {
    let id: String
    let category: FAQCategory
    let question: String
    let answer: String
}

enum CircleLinkFAQ {
    static let items: [FAQItem] = [
        .init(id: "account-age", category: .account,
              question: "Why does CircleLink ask for my age?",
              answer: "CircleLink uses your birth date to confirm that you meet the minimum age requirement. Your public profile shows a calculated age, not your birth date."),
        .init(id: "account-edit", category: .account,
              question: "How do I update my profile?",
              answer: "Open Profile and choose Edit Profile. You can update the information currently available in the profile form."),
        .init(id: "connect-likes", category: .connect,
              question: "How do likes and connections work?",
              answer: "Use Connect to pass or say hi to profiles. A mutual connection can make a direct chat available. Check Connect activity for the current status."),
        .init(id: "communities", category: .communities,
              question: "What can I do in a community?",
              answer: "Communities bring people together around shared interests. Available actions depend on your membership and the controls shown in that community."),
        .init(id: "chats-manage", category: .chats,
              question: "How do mute, hide, and pin work?",
              answer: "Mute pauses notifications for a chat. Hide removes it from the main list without deleting its history. Pin keeps selected chats near the top of the list."),
        .init(id: "safety-block", category: .safety,
              question: "What happens when I block someone?",
              answer: "Blocking limits interactions with that person. You can review and unblock people from Settings under Blocked People."),
        .init(id: "safety-report", category: .safety,
              question: "How do I report a concern?",
              answer: "Use the Report action where it is available. For concerns you cannot report in the app, contact Support and avoid including sensitive message content unless needed."),
        .init(id: "preferences-notifications", category: .preferences,
              question: "What is the difference between notifications and reminders?",
              answer: "Notifications cover app activity delivered through push. Reminders are an optional daily alert to check Connect activity. You can control them separately in Settings."),
        .init(id: "privacy", category: .privacy,
              question: "Where can I read the privacy policy?",
              answer: "Open Settings, then Privacy Policy under Legal. Contact Support if you have a privacy question not answered there."),
        .init(id: "delete", category: .account,
              question: "How do I delete my account?",
              answer: "Open Settings and choose Delete Account. The confirmation screen explains deactivation, the recovery period, and scheduled cleanup before you continue.")
    ]
}

struct FAQView: View {
    @State private var searchText = ""

    private var filteredItems: [FAQItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return CircleLinkFAQ.items
        }
        return CircleLinkFAQ.items.filter {
            $0.question.localizedCaseInsensitiveContains(searchText)
                || $0.answer.localizedCaseInsensitiveContains(searchText)
                || $0.category.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(FAQCategory.allCases, id: \.self) { category in
                let items = filteredItems.filter { $0.category == category }
                if !items.isEmpty {
                    Section(category.rawValue) {
                        ForEach(items) { item in
                            DisclosureGroup {
                                Text(item.answer)
                                    .font(CLTypography.body)
                                    .foregroundStyle(CLColor.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, CLSpacing.xs)
                            } label: {
                                Text(item.question)
                                    .font(CLTypography.body)
                                    .foregroundStyle(CLColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .tint(CLColor.primary)
                        }
                    }
                    .listRowBackground(CLColor.surface)
                }
            }

            if filteredItems.isEmpty {
                Section {
                    VStack(spacing: CLSpacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(CLColor.inkMuted)
                        Text("No help topics found")
                            .font(CLTypography.headline)
                            .foregroundStyle(CLColor.ink)
                        Text("Try a different search term.")
                            .font(CLTypography.body)
                            .foregroundStyle(CLColor.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CLSpacing.xl)
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(CLColor.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clCanvasBackground()
        .searchable(text: $searchText, prompt: "Search help")
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
