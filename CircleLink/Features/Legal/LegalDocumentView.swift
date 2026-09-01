import SwiftUI

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CLSpacing.lg) {
                if document.status == .draft {
                    draftBanner
                }

                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    Text(document.title)
                        .font(CLTypography.largeTitle)
                        .foregroundStyle(CLColor.ink)
                        .accessibilityAddTraits(.isHeader)

                    if let lastUpdated = document.lastUpdated,
                       let date = lastUpdated.date() {
                        Text("Last updated \(date, format: .dateTime.year().month(.wide).day())")
                            .font(CLTypography.footnote)
                            .foregroundStyle(CLColor.inkMuted)
                    } else {
                        Text("Last updated: Pending legal review")
                            .font(CLTypography.footnote)
                            .foregroundStyle(CLColor.inkMuted)
                    }
                }

                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: CLSpacing.sm) {
                        Text(section.title)
                            .font(CLTypography.title2)
                            .foregroundStyle(CLColor.ink)
                            .accessibilityAddTraits(.isHeader)

                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(CLTypography.body)
                                .foregroundStyle(CLColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, CLSpacing.screenHorizontal)
            .padding(.vertical, CLSpacing.lg)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .textSelection(.enabled)
        }
        .clCanvasBackground()
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var draftBanner: some View {
        Label {
            Text("Draft for product review. Legal approval is required before production release.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "doc.badge.clock")
                .accessibilityHidden(true)
        }
        .font(CLTypography.callout)
        .foregroundStyle(CLColor.ink)
        .padding(CLSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CLColor.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous)
                .stroke(CLColor.hairlineStrong, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
