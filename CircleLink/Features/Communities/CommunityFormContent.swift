import PhotosUI
import SwiftUI
import UIKit

struct CommunityFormDraft: Equatable {
    var name: String
    var description: String
    var interestTag: String
    var selectedCoverData: Data?
    var removesExistingCover: Bool

    private let originalName: String
    private let originalDescription: String
    private let originalInterestTag: String
    let originalCoverURL: URL?

    init(community: Community? = nil) {
        name = community?.name ?? ""
        description = community?.description ?? ""
        interestTag = community?.interestTag ?? ProfileInterests.presets.first ?? "Sports"
        selectedCoverData = nil
        removesExistingCover = false
        originalName = name
        originalDescription = description
        originalInterestTag = interestTag
        originalCoverURL = community?.coverImageURL
    }

    var isDirty: Bool {
        name != originalName || description != originalDescription
            || interestTag != originalInterestTag || selectedCoverData != nil || removesExistingCover
    }

    var coverEdit: CommunityCoverEdit {
        if let selectedCoverData { return .replace(selectedCoverData) }
        if removesExistingCover { return .remove }
        return .unchanged
    }
}

struct CommunityFormContent: View {
    @Binding var draft: CommunityFormDraft
    let showsInterest: Bool
    let isBusy: Bool

    @State private var photoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var photoErrorMessage: String?
    @State private var isLoadingPhoto = false
    @State private var loadGeneration = 0
    @State private var hasEditedName = false

    var body: some View {
        VStack(alignment: .leading, spacing: CLSpacing.xl) {
            coverSection
            detailsSection
            if showsInterest { interestSection }
        }
        .onChange(of: photoItem) { item in Task { await loadPhoto(item) } }
        .onDisappear { loadGeneration += 1 }
    }

    private var coverSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            sectionTitle("Cover")
            coverHero
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous).stroke(CLColor.hairline))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: CLSpacing.sm) { coverActions }
                VStack(alignment: .leading, spacing: CLSpacing.sm) { coverActions }
            }
            if let photoErrorMessage { errorText(photoErrorMessage, prefix: "Photo error") }
        }
    }

    @ViewBuilder private var coverHero: some View {
        if isLoadingPhoto {
            CLColor.surfaceSoft.overlay { ProgressView().tint(CLColor.primary) }
                .accessibilityLabel("Loading cover photo")
        } else if let previewImage {
            Image(uiImage: previewImage).resizable().scaledToFill().clipped()
                .accessibilityLabel("Selected community cover")
        } else if !draft.removesExistingCover, let url = draft.originalCoverURL {
            AsyncImage(url: url) { phase in
                if case let .success(image) = phase { image.resizable().scaledToFill() }
                else { coverPlaceholder }
            }
            .clipped()
            .accessibilityLabel("Current community cover")
        } else {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            CLColor.surfaceSoft
            VStack(spacing: CLSpacing.xs) {
                Image(systemName: "photo.on.rectangle.angled").font(.title).foregroundStyle(CLColor.primary)
                Text("Add a welcoming cover").font(CLTypography.subheadline).foregroundStyle(CLColor.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var coverActions: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            Label(hasVisibleCover ? "Change Photo" : "Add Photo", systemImage: "photo")
                .frame(maxWidth: .infinity).frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
        }
        .buttonStyle(CLSecondaryButtonStyle())
        .disabled(isBusy || isLoadingPhoto)

        if hasVisibleCover {
            Button(role: .destructive) {
                loadGeneration += 1
                photoItem = nil
                previewImage = nil
                draft.selectedCoverData = nil
                draft.removesExistingCover = draft.originalCoverURL != nil
                photoErrorMessage = nil
            } label: {
                Label("Remove Photo", systemImage: "trash")
                    .frame(maxWidth: .infinity).frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
            }
            .buttonStyle(CLSecondaryButtonStyle())
            .disabled(isBusy || isLoadingPhoto)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            sectionTitle("Details")
            fieldCard {
                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    Text("Name").font(CLTypography.footnote).foregroundStyle(CLColor.inkSecondary)
                    TextField("Community name", text: $draft.name, axis: .vertical)
                        .font(CLTypography.body).lineLimit(1 ... 3).accessibilityLabel("Community name")
                    characterCounter(count: CommunityContentPolicy.trimmed(draft.name).count,
                                     limit: CommunityContentPolicy.nameLimit, label: "Name")
                }
            }
            fieldCard {
                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    Text("Description").font(CLTypography.footnote).foregroundStyle(CLColor.inkSecondary)
                    TextField("What brings this community together?", text: $draft.description, axis: .vertical)
                        .font(CLTypography.body).lineLimit(4 ... 12).accessibilityLabel("Community description")
                    characterCounter(count: CommunityContentPolicy.trimmed(draft.description).count,
                                     limit: CommunityContentPolicy.descriptionLimit, label: "Description")
                }
            }
            if let validationMessage { errorText(validationMessage, prefix: "Validation error") }
        }
        .onChange(of: draft.name) { value in
            hasEditedName = true
            let bounded = CommunityContentPolicy.boundedNameDraft(value)
            if bounded != value { draft.name = bounded }
        }
        .onChange(of: draft.description) { value in
            let bounded = CommunityContentPolicy.boundedDescriptionDraft(value)
            if bounded != value { draft.description = bounded }
        }
    }

    private var interestSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            sectionTitle("Interest")
            fieldCard {
                Picker("Community interest", selection: $draft.interestTag) {
                    ForEach(ProfileInterests.presets, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var hasVisibleCover: Bool {
        previewImage != nil || (!draft.removesExistingCover && draft.originalCoverURL != nil)
    }

    private var validationMessage: String? {
        do { _ = try CommunityContentPolicy.validate(name: draft.name, description: draft.description); return nil }
        catch CommunityContentValidationError.nameRequired where !hasEditedName && draft.name.isEmpty { return nil }
        catch { return error.localizedDescription }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoadingPhoto = true
        photoErrorMessage = nil
        defer { if generation == loadGeneration { isLoadingPhoto = false } }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                throw CommunityFormPhotoError.unreadable
            }
            guard generation == loadGeneration, !Task.isCancelled else { return }
            draft.selectedCoverData = data
            draft.removesExistingCover = false
            previewImage = image
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            photoItem = nil
            photoErrorMessage = "Couldn’t load the selected photo."
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(CLTypography.headline).foregroundStyle(CLColor.ink).accessibilityAddTraits(.isHeader)
    }

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().padding(CLSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(CLColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous).stroke(CLColor.hairline))
    }

    private func characterCounter(count: Int, limit: Int, label: String) -> some View {
        Text("\(count)/\(limit)").font(CLTypography.caption)
            .foregroundStyle(count > limit ? CLColor.error : CLColor.inkMuted)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("\(label), \(count) of \(limit) characters")
    }

    private func errorText(_ message: String, prefix: String) -> some View {
        Text(message).font(CLTypography.footnote).foregroundStyle(CLColor.error)
            .fixedSize(horizontal: false, vertical: true).accessibilityLabel("\(prefix): \(message)")
    }
}

private enum CommunityFormPhotoError: Error { case unreadable }
