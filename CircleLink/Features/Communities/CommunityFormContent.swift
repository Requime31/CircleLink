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
        CLPhotoPickerSection(
            selection: $photoItem,
            title: "Cover",
            actionTitle: hasVisibleCover ? "Change Photo" : "Add Photo",
            isDisabled: isBusy || isLoadingPhoto,
            errorMessage: photoErrorMessage,
            removeTitle: hasVisibleCover ? "Remove Photo" : nil,
            onRemove: removeCover
        ) {
            coverHero
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CLRadius.xl, style: .continuous).stroke(CLColor.hairline))
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

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.md) {
            CLSectionHeader("Details")
            CLFieldCard {
                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    CLFormLabel(title: "Name")
                    TextField("Community name", text: $draft.name, axis: .vertical)
                        .font(CLTypography.body).lineLimit(1 ... 3).accessibilityLabel("Community name")
                    CLCharacterCounter(count: CommunityContentPolicy.trimmed(draft.name).count,
                                       limit: CommunityContentPolicy.nameLimit, label: "Name")
                }
            }
            CLFieldCard {
                VStack(alignment: .leading, spacing: CLSpacing.xs) {
                    CLFormLabel(title: "Description")
                    TextField("What brings this community together?", text: $draft.description, axis: .vertical)
                        .font(CLTypography.body).lineLimit(4 ... 12).accessibilityLabel("Community description")
                    CLCharacterCounter(count: CommunityContentPolicy.trimmed(draft.description).count,
                                       limit: CommunityContentPolicy.descriptionLimit, label: "Description")
                }
            }
            if let validationMessage { CLValidationMessage(message: validationMessage) }
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
            CLSectionHeader("Interest")
            CLFieldCard {
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

    private func removeCover() {
        loadGeneration += 1
        photoItem = nil
        previewImage = nil
        draft.selectedCoverData = nil
        draft.removesExistingCover = draft.originalCoverURL != nil
        photoErrorMessage = nil
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

}

private enum CommunityFormPhotoError: Error { case unreadable }
