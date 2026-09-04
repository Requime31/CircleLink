import PhotosUI
import SwiftUI

struct CLPhotoPickerConfiguration: Equatable {
    let title: String
    var actionTitle = "Add Photo"
    var removeTitle: String? = nil
    var isDisabled = false

    var canPick: Bool { isDisabled == false }
    var canRemove: Bool { isDisabled == false && removeTitle != nil }
}

struct CLPlaceholderMedia: View {
    var systemImage = "photo"
    var label = "No photo"

    var body: some View {
        ZStack {
            CLColor.surfaceSoft
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(CLColor.inkMuted)
                .accessibilityHidden(true)
        }
        .accessibilityLabel(label)
    }
}

struct CLMediaThumbnail: View {
    let url: URL?
    var accessibilityLabel = "Photo"
    var cornerRadius: CGFloat = CLRadius.sm

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image): image.resizable().scaledToFill()
            case .empty: CLPlaceholderMedia(systemImage: "photo", label: "Loading photo").overlay { ProgressView() }
            case .failure: CLPlaceholderMedia(systemImage: "photo.badge.exclamationmark", label: "Photo unavailable")
            @unknown default: CLPlaceholderMedia()
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(CLColor.hairline))
        .accessibilityLabel(accessibilityLabel)
    }
}

struct CLPhotoPickerSection<Preview: View>: View {
    @Binding var selection: PhotosPickerItem?
    let title: String
    var actionTitle = "Add Photo"
    var isDisabled = false
    var errorMessage: String? = nil
    var removeTitle: String? = nil
    var onRemove: (() -> Void)? = nil
    private let preview: Preview

    init(
        selection: Binding<PhotosPickerItem?>,
        title: String,
        actionTitle: String = "Add Photo",
        isDisabled: Bool = false,
        errorMessage: String? = nil,
        removeTitle: String? = nil,
        onRemove: (() -> Void)? = nil,
        @ViewBuilder preview: () -> Preview
    ) {
        _selection = selection
        self.title = title
        self.actionTitle = actionTitle
        self.isDisabled = isDisabled
        self.errorMessage = errorMessage
        self.removeTitle = removeTitle
        self.onRemove = onRemove
        self.preview = preview()
    }

    var body: some View {
        CLFormSection(title) {
            preview
            ViewThatFits(in: .horizontal) {
                HStack(spacing: CLSpacing.sm) { actions }
                VStack(spacing: CLSpacing.sm) { actions }
            }

            if let errorMessage { CLValidationMessage(message: errorMessage) }
        }
    }

    @ViewBuilder private var actions: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            Label(actionTitle, systemImage: "photo")
                .frame(maxWidth: .infinity)
                .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        }
        .buttonStyle(CLSecondaryButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(actionTitle)

        if let removeTitle, let onRemove {
            Button(removeTitle, role: .destructive, action: onRemove)
                .buttonStyle(CLSecondaryButtonStyle())
                .disabled(isDisabled)
                .accessibilityLabel(removeTitle)
        }
    }
}

struct CLMediaGridConfiguration: Equatable {
    var minimumItemWidth: CGFloat = 96
    var spacing: CGFloat = CLSpacing.xs
    var aspectRatio: CGFloat = 1
}

struct CLMediaGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var configuration = CLMediaGridConfiguration()
    private let content: (Item) -> Content

    init(
        items: [Item],
        configuration: CLMediaGridConfiguration = .init(),
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.configuration = configuration
        self.content = content
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: configuration.minimumItemWidth), spacing: configuration.spacing)],
            spacing: configuration.spacing
        ) {
            ForEach(items) { item in
                content(item).aspectRatio(configuration.aspectRatio, contentMode: .fit)
            }
        }
    }
}

struct CLAvatarStack: View {
    let avatars: [URL?]
    var maximumVisible = 4
    var avatarSize: CGFloat = 36

    var body: some View {
        HStack(spacing: -(avatarSize * 0.28)) {
            ForEach(Array(avatars.prefix(maximumVisible).enumerated()), id: \.offset) { _, url in
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        CLPlaceholderMedia(systemImage: "person.fill", label: "Person")
                    }
                }
                .frame(width: avatarSize, height: avatarSize)
                .clAvatarClip()
                .overlay(CLAvatar.shape().stroke(CLColor.surface, lineWidth: 2))
                .accessibilityHidden(true)
            }
            if avatars.count > maximumVisible {
                Text("+\(avatars.count - maximumVisible)")
                    .font(CLTypography.caption)
                    .frame(width: avatarSize, height: avatarSize)
                    .background(CLColor.surfaceSoft)
                    .clAvatarClip()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(avatars.count) people")
    }
}

struct CLPostComposerLayout<Media: View, Submit: View>: View {
    @Binding var text: String
    let prompt: String
    var characterLimit: Int? = nil
    var validationMessage: String? = nil
    private let media: Media
    private let submit: Submit

    init(
        text: Binding<String>,
        prompt: String,
        characterLimit: Int? = nil,
        validationMessage: String? = nil,
        @ViewBuilder media: () -> Media,
        @ViewBuilder submit: () -> Submit
    ) {
        _text = text
        self.prompt = prompt
        self.characterLimit = characterLimit
        self.validationMessage = validationMessage
        self.media = media()
        self.submit = submit()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.lg) {
            CLFieldCard {
                TextField(prompt, text: $text, axis: .vertical)
                    .font(CLTypography.body)
                    .lineLimit(4 ... 12)
                    .accessibilityLabel("Post text")
                if let characterLimit {
                    CLCharacterCounter(count: text.count, limit: characterLimit, label: "Post text")
                }
            }
            media
            if let validationMessage { CLValidationMessage(message: validationMessage) }
            submit
        }
    }
}

struct CLPostComposerConfiguration: Equatable {
    let characterLimit: Int?

    func validationMessage(for text: String) -> String? {
        guard let characterLimit, text.count > characterLimit else { return nil }
        return "Post text must be \(characterLimit) characters or fewer."
    }

    func canSubmit(text: String, hasMedia: Bool, isSubmitting: Bool) -> Bool {
        isSubmitting == false
            && (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || hasMedia)
            && validationMessage(for: text) == nil
    }
}
