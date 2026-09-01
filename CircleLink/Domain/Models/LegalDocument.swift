import Foundation

struct LegalDocument: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case draft
        case approved
    }

    enum Kind: String, Identifiable, Sendable {
        case termsOfService
        case privacyPolicy

        var id: String { rawValue }
    }

    let kind: Kind
    let status: Status
    let title: String
    /// Civil date, not an instant, so travel cannot change the displayed review day.
    let lastUpdated: LegalDate?
    let sections: [LegalSection]

    var id: String { kind.id }
}

struct LegalDate: Equatable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    func date(calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }
}

struct LegalSection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let paragraphs: [String]
}

enum LegalDocuments {
    static let termsOfService = LegalDocument(
        kind: .termsOfService,
        status: .draft,
        title: "Terms of Service",
        lastUpdated: nil,
        sections: [
            section(
                "terms-draft-status",
                "Draft Status",
                "This document is a product draft for CircleLink. It requires legal review before the app is released and is not legal advice."
            ),
            section(
                "terms-service-purpose",
                "About CircleLink",
                "CircleLink is a community messenger where adults can discover communities, publish posts, connect with other people, and exchange messages. Features may change as the product develops."
            ),
            section(
                "terms-eligibility",
                "Eligibility and Accounts",
                "You must be at least 18 years old to use CircleLink. You are responsible for providing accurate account information and for activity performed through your account.",
                "Do not access another person’s account or attempt to bypass account, safety, or eligibility controls."
            ),
            section(
                "terms-user-content",
                "Your Content",
                "You are responsible for the profile information, community posts, messages, images, and other content you submit. Only share content that you are permitted to share.",
                "A production version of these terms must define the permissions needed to host, display, transmit, and moderate user content. Legal counsel must review that language before release."
            ),
            section(
                "terms-conduct",
                "Acceptable Conduct",
                "Do not use CircleLink to harass, threaten, impersonate, exploit, defraud, spam, or unlawfully discriminate against others. Do not publish illegal content, violate another person’s privacy, or interfere with the service or its security."
            ),
            section(
                "terms-moderation-blocking",
                "Moderation, Reporting, and Blocking",
                "CircleLink includes tools for reporting and blocking. Reports may be reviewed and content or access may be restricted when needed for safety, service integrity, or compliance.",
                "Blocking reduces interactions between accounts, but no moderation or blocking system can prevent every unwanted interaction."
            ),
            section(
                "terms-services",
                "Service Providers",
                "CircleLink currently relies on third-party infrastructure, including Firebase services, Supabase storage, and Apple and Firebase push-notification systems. Their availability and separate terms may affect parts of the service."
            ),
            section(
                "terms-account-deletion",
                "Account Deletion",
                "CircleLink is expected to provide an in-app account deletion process before production release. The final terms must explain the process and any lawful exceptions after the product and retention policy are approved.",
                "Until a production support channel is configured, the support contact is: [Support email to be added before release]."
            ),
            section(
                "terms-changes",
                "Changes to These Terms",
                "These draft terms may change as CircleLink develops. Before production, the app must identify how material changes are communicated and when updated terms take effect."
            ),
            section(
                "terms-contact",
                "Contact",
                "Questions about these draft terms can be sent to: [Legal or support email to be added before release]."
            )
        ]
    )

    static let privacyPolicy = LegalDocument(
        kind: .privacyPolicy,
        status: .draft,
        title: "Privacy Policy",
        lastUpdated: nil,
        sections: [
            section(
                "privacy-draft-status",
                "Draft Status",
                "This privacy policy is a product draft for CircleLink. It requires legal review before the app is released and is not legal advice."
            ),
            section(
                "privacy-overview",
                "Overview",
                "This draft describes the information CircleLink currently expects to handle when adults use community, messaging, connection, profile, moderation, and notification features."
            ),
            section(
                "privacy-data-categories",
                "Information We Handle",
                "Account and profile information may include authentication identifiers, display name, profile photo, interests, biography, age confirmation, and a private date of birth.",
                "Activity information may include communities joined, posts, messages, connection activity, reports, blocks, notification preferences, and device push tokens.",
                "Technical providers may process device, network, diagnostic, authentication, and storage information needed to operate their services. The final policy must be checked against the production configuration and provider disclosures."
            ),
            section(
                "privacy-use",
                "How Information Is Used",
                "Information is used to authenticate accounts, provide profiles and community features, deliver messages and notifications, support connections, enforce age eligibility, respond to reports, apply blocks, protect the service, and troubleshoot operation."
            ),
            section(
                "privacy-visibility",
                "Visibility and User Content",
                "Profile details and content intended for communities or other members may be visible to other signed-in users. Private account data, including the full date of birth, is intended only for the account owner and eligibility processing.",
                "Messages and posts are processed so they can be stored, delivered, and displayed. Avoid sharing sensitive information that is not needed for the conversation."
            ),
            section(
                "privacy-providers",
                "Service Providers",
                "CircleLink currently uses Firebase for authentication, database, and messaging services; Supabase for image storage; Apple Push Notification service; and Firebase Cloud Messaging for push delivery.",
                "These services may process information according to CircleLink’s technical configuration and their own terms. The production policy must list the final providers and links after legal review."
            ),
            section(
                "privacy-push",
                "Push Notifications",
                "If notifications are enabled, CircleLink stores a device push token and sends notification data through Apple and Firebase messaging systems. Notification permission can be changed in iOS Settings, and CircleLink’s notification preference can be changed in the app."
            ),
            section(
                "privacy-moderation",
                "Reports and Blocking",
                "Reports currently include account identifiers, a selected reason, and supported chat or community context. This information may be reviewed to investigate safety concerns and enforce product rules. Blocking information is used to reduce interactions and filter affected accounts from supported experiences."
            ),
            section(
                "privacy-retention-deletion",
                "Retention and Account Deletion",
                "Information is retained while needed to operate CircleLink and for purposes that must be defined in the production retention policy. This draft does not promise a fixed retention period.",
                "CircleLink is expected to provide in-app account deletion before production. The final policy must explain what is deleted, what may need to be retained, the legal basis, and the applicable timing after those decisions are approved."
            ),
            section(
                "privacy-age",
                "Age Eligibility",
                "CircleLink is intended only for people aged 18 and older. A full date of birth is used to confirm eligibility and derive the age shown on a profile; it is stored separately from the public profile data."
            ),
            section(
                "privacy-changes",
                "Changes to This Policy",
                "This draft may change as CircleLink develops. Before production, the app must identify how material policy changes are communicated and when an updated policy takes effect."
            ),
            section(
                "privacy-contact",
                "Contact",
                "Privacy questions and account requests can be sent to: [Privacy or support email to be added before release]."
            )
        ]
    )

    static let all = [termsOfService, privacyPolicy]

    private static func section(_ id: String, _ title: String, _ paragraphs: String...) -> LegalSection {
        LegalSection(id: id, title: title, paragraphs: paragraphs)
    }
}
