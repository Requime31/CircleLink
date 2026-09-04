import PhotosUI
import SwiftUI

struct CLProfileIdentity: View {
    let name: String
    var detail: String? = nil
    var avatarURL: URL? = nil
    var avatarBase64: String? = nil
    var avatarSize: CGFloat = 96

    var body: some View {
        VStack(spacing: CLSpacing.sm) {
            AvatarImageView(localPreview: nil, avatarBase64: avatarBase64, avatarURL: avatarURL, size: avatarSize)
                .accessibilityHidden(true)
            Text(name)
                .font(CLTypography.title)
                .foregroundStyle(CLColor.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail).font(CLTypography.callout).foregroundStyle(CLColor.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CLProfileAboutSection: View {
    let text: String

    var body: some View {
        CLCard {
            CLSectionHeader("About")
            Text(text).font(CLTypography.body).foregroundStyle(CLColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CLProfileInterestsSection: View {
    let interests: [String]

    var body: some View {
        CLCard {
            CLSectionHeader("Interests")
            CLFlowLayout {
                ForEach(interests, id: \.self) { CLChip(title: $0, isEmphasized: true) }
            }
        }
    }
}

struct CLProfileCommunitiesSection<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        CLCard {
            CLSectionHeader("Communities")
            content
        }
    }
}

struct CLProfileStat: Identifiable, Equatable {
    let id: String
    let value: String
    let label: String
}

struct CLProfileStatsRow: View {
    let stats: [CLProfileStat]

    var body: some View {
        HStack(alignment: .top, spacing: CLSpacing.sm) {
            ForEach(stats) { stat in
                VStack(spacing: CLSpacing.xxs) {
                    Text(stat.value).font(CLTypography.headline).foregroundStyle(CLColor.ink)
                    Text(stat.label).font(CLTypography.caption).foregroundStyle(CLColor.inkMuted)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct CLProfileAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var isEmphasized = false
    let action: () -> Void
}

struct CLProfileActionBar: View {
    let actions: [CLProfileAction]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CLSpacing.sm) { buttons }
            VStack(spacing: CLSpacing.sm) { buttons }
        }
    }

    @ViewBuilder private var buttons: some View {
        ForEach(actions) { item in
            Button(action: item.action) { Label(item.title, systemImage: item.systemImage).frame(maxWidth: .infinity) }
                .buttonStyle(AnyCLButtonStyle(style: item.isEmphasized ? .emphasis : .secondary))
        }
    }
}

struct CLAvatarPicker<Preview: View>: View {
    @Binding var selection: PhotosPickerItem?
    var hasPhoto: Bool
    var isDisabled = false
    let onRemove: () -> Void
    private let preview: Preview

    init(
        selection: Binding<PhotosPickerItem?>,
        hasPhoto: Bool,
        isDisabled: Bool = false,
        onRemove: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview
    ) {
        _selection = selection
        self.hasPhoto = hasPhoto
        self.isDisabled = isDisabled
        self.onRemove = onRemove
        self.preview = preview()
    }

    var body: some View {
        VStack(spacing: CLSpacing.sm) {
            preview
            PhotosPicker(selection: $selection, matching: .images) {
                Text(hasPhoto ? "Change Photo" : "Add Photo")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .disabled(isDisabled)
            if hasPhoto {
                Button("Remove Photo", role: .destructive, action: onRemove)
                    .foregroundStyle(CLColor.error)
                    .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    .disabled(isDisabled)
            }
        }
    }
}
