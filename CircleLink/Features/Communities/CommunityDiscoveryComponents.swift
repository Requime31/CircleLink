import Foundation
import SwiftUI

struct CommunitySearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: CLSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)

            TextField("Search communities…", text: $query)
                .font(CLTypography.body)
                .foregroundStyle(CLColor.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(isFocused)
                .accessibilityLabel("Search communities")

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CLColor.inkMuted)
                        .frame(
                            minWidth: AccessibilityHelpers.minimumTouchTarget,
                            minHeight: AccessibilityHelpers.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .clTextFieldChrome(isFocused: isFocused.wrappedValue)
        .padding(.horizontal, CLSpacing.screenHorizontal)
    }
}

struct CommunityCategoryChips: View {
    let interestTags: [String]
    @Binding var selectedInterestTag: String?

    private var sortedInterestTags: [String] {
        Array(
            Set(
                interestTags
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: CLSpacing.xs) {
                CLChip(
                    title: "All",
                    isSelected: selectedInterestTag == nil,
                    accessibilityLabelText: "All categories",
                    action: { selectedInterestTag = nil }
                )

                ForEach(sortedInterestTags, id: \.self) { interestTag in
                    CLChip(
                        title: interestTag,
                        isSelected: selectedInterestTag == interestTag,
                        accessibilityLabelText: "\(interestTag) category",
                        action: { selectedInterestTag = interestTag }
                    )
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
        }
        .accessibilityLabel("Community categories")
    }
}

struct CommunitySectionHeader: View {
    let title: String
    var onSeeAll: (() -> Void)?

    init(title: String, onSeeAll: (() -> Void)? = nil) {
        self.title = title
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        HStack(spacing: CLSpacing.md) {
            Text(title)
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: CLSpacing.xs)

            if let onSeeAll {
                Button("See all", action: onSeeAll)
                    .font(CLTypography.callout.weight(.medium))
                    .foregroundStyle(CLColor.primary)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .accessibilityLabel("See all \(title.lowercased())")
            }
        }
        .padding(.horizontal, CLSpacing.screenHorizontal)
    }
}

struct CommunityMetadataPresentation: Equatable, Sendable {
    let visualText: String
    let accessibilityText: String

    static func make(
        for community: Community,
        relativeTo referenceDate: Date = Date(),
        locale: Locale = .current
    ) -> CommunityMetadataPresentation {
        let visualMembers = memberCountText(
            community.memberCount,
            locale: locale,
            usesCompactNotation: true
        )
        let spokenMembers = memberCountText(
            community.memberCount,
            locale: locale,
            usesCompactNotation: false
        )

        guard let createdAt = community.createdAt else {
            return CommunityMetadataPresentation(
                visualText: visualMembers,
                accessibilityText: "\(community.interestTag), \(spokenMembers)"
            )
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        let relativeDate = formatter.localizedString(for: createdAt, relativeTo: referenceDate)

        return CommunityMetadataPresentation(
            visualText: "\(relativeDate) • \(visualMembers)",
            accessibilityText: "\(community.interestTag), created \(relativeDate), \(spokenMembers)"
        )
    }

    private static func memberCountText(
        _ count: Int,
        locale: Locale,
        usesCompactNotation: Bool
    ) -> String {
        let normalizedCount = max(0, count)
        let formattedCount: String
        if usesCompactNotation {
            formattedCount = normalizedCount.formatted(
                .number.notation(.compactName).locale(locale)
            )
        } else {
            formattedCount = normalizedCount.formatted(.number.locale(locale))
        }
        return normalizedCount == 1 ? "\(formattedCount) member" : "\(formattedCount) members"
    }
}

struct CommunityCompactRow: View {
    let community: Community
    var referenceDate: Date = Date()

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var metadata: CommunityMetadataPresentation {
        .make(for: community, relativeTo: referenceDate)
    }

    var body: some View {
        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: CLSpacing.md) {
            CommunityArtworkView(community: community, cornerRadius: CLRadius.md)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                Text(CommunityContentPolicy.safeDisplayName(community.name))
                    .font(CLTypography.headline)
                    .foregroundStyle(CLColor.ink)

                Text(community.interestTag)
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkSecondary)

                Text(metadata.visualText)
                    .font(CLTypography.footnote)
                    .foregroundStyle(CLColor.inkMuted)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(CLTypography.footnote.weight(.semibold))
                .foregroundStyle(CLColor.inkMuted)
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? CLSpacing.xxs : 0)
                .accessibilityHidden(true)
        }
        .padding(.vertical, CLSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CommunityContentPolicy.safeDisplayName(community.name))
        .accessibilityValue(metadata.accessibilityText)
    }
}

struct CommunityRows: View {
    let communities: [Community]
    var referenceDate: Date = Date()
    let onSelect: (Community) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(communities.enumerated()), id: \.element.id) { index, community in
                Button {
                    onSelect(community)
                } label: {
                    CommunityCompactRow(community: community, referenceDate: referenceDate)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Opens community details")

                if index < communities.count - 1 {
                    Divider()
                        .overlay(CLColor.hairline)
                        .padding(.leading, 64 + CLSpacing.md)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, CLSpacing.screenHorizontal)
    }
}
