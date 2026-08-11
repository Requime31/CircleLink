import PhotosUI
import SwiftUI
import UIKit

/// Compose / edit sheet for owner profile posts: text and/or one photo.
struct ComposeProfilePostSheet: View {
    enum Mode: Identifiable, Equatable {
        case create
        case edit(ProfilePost)

        var id: String {
            switch self {
            case .create:
                return "create"
            case let .edit(post):
                return "edit-\(post.id)"
            }
        }

        var editingPost: ProfilePost? {
            if case let .edit(post) = self { return post }
            return nil
        }
    }

    @ObservedObject var viewModel: ProfileViewModel
    let mode: Mode
    let onDismiss: () -> Void

    @State private var text = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var previewImage: UIImage?
    /// Existing remote image kept while editing (cleared when user removes/replaces).
    @State private var keptRemoteImageURL: URL?
    @State private var isLoadingPhoto = false
    @State private var remotePreviewFailed = false
    @State private var localErrorMessage: String?
    @FocusState private var isTextFocused: Bool
    @State private var didPrefill = false

    private var isEditing: Bool { mode.editingPost != nil }

    private var canSubmit: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = selectedImageData != nil || keptRemoteImageURL != nil
        return (hasText || hasImage) && !viewModel.isPosting && !isLoadingPhoto
    }

    private var showsPhotoChrome: Bool {
        previewImage != nil || (keptRemoteImageURL != nil && remotePreviewFailed)
    }

    private var bannerError: String? {
        localErrorMessage ?? viewModel.postErrorMessage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    TextField(
                        "Share something on your profile…",
                        text: $text,
                        axis: .vertical
                    )
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.ink)
                    .lineLimit(4 ... 12)
                    .focused($isTextFocused)
                    .clTextFieldChrome()
                    .accessibilityLabel("Post text")

                    photoSection

                    if let errorMessage = bannerError {
                        Text(errorMessage)
                            .font(CLTypography.footnote)
                            .foregroundStyle(CLColor.error)
                            .padding(CLSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CLColor.errorSoft)
                            .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                            .accessibilityLabel("Post error: \(errorMessage)")
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if viewModel.isPosting {
                            ProgressView()
                                .tint(CLColor.onPrimary)
                        } else {
                            Text(isEditing ? "Save" : "Post")
                        }
                    }
                    .buttonStyle(CLPrimaryButtonStyle())
                    .disabled(!canSubmit)
                    .accessibilityLabel(isEditing ? "Save post" : "Publish post")
                }
                .padding(CLSpacing.md)
            }
            .clCanvasBackground()
            .navigationTitle(isEditing ? "Edit Post" : "New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.clearPostError()
                        onDismiss()
                    }
                    .disabled(viewModel.isPosting)
                }
            }
            .interactiveDismissDisabled(viewModel.isPosting)
            .task {
                await prefillIfNeeded()
            }
            .onAppear {
                isTextFocused = true
            }
            .onChange(of: selectedPhotoItem) { item in
                Task { await loadPhoto(item) }
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            if showsPhotoChrome {
                photoPreview

                HStack(spacing: CLSpacing.sm) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("Change Photo")
                            .font(CLTypography.button)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    }
                    .buttonStyle(CLSecondaryButtonStyle())
                    .disabled(isLoadingPhoto || viewModel.isPosting)
                    .accessibilityLabel("Change post photo")

                    Button("Remove") {
                        clearPhoto()
                    }
                    .buttonStyle(CLSecondaryButtonStyle())
                    .disabled(isLoadingPhoto || viewModel.isPosting)
                    .accessibilityLabel("Remove post photo")
                }
            } else if isLoadingPhoto {
                ZStack {
                    CLColor.surfaceSoft
                    ProgressView()
                        .tint(CLColor.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                .accessibilityLabel("Loading photo")
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add Photo", systemImage: "photo")
                        .font(CLTypography.button)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .disabled(viewModel.isPosting)
                .accessibilityLabel("Add post photo")
            }
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let preview = previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                .accessibilityLabel("Selected photo preview")
        } else {
            ZStack {
                CLColor.surfaceSoft
                VStack(spacing: CLSpacing.xs) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(CLColor.inkMuted)
                    Text("Couldn’t load photo")
                        .font(CLTypography.footnote)
                        .foregroundStyle(CLColor.inkMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .accessibilityLabel("Could not load photo")
        }
    }

    private func prefillIfNeeded() async {
        guard !didPrefill, let post = mode.editingPost else { return }
        didPrefill = true
        text = post.text ?? ""
        keptRemoteImageURL = post.imageURL
        guard let url = post.imageURL else { return }

        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            previewImage = try await ImageLoader.shared.load(from: url)
            remotePreviewFailed = previewImage == nil
        } catch {
            guard !Task.isCancelled else { return }
            previewImage = nil
            remotePreviewFailed = true
        }
    }

    private func clearPhoto() {
        selectedPhotoItem = nil
        selectedImageData = nil
        previewImage = nil
        keptRemoteImageURL = nil
        remotePreviewFailed = false
        isLoadingPhoto = false
        localErrorMessage = nil
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        localErrorMessage = nil
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                selectedImageData = data
                previewImage = UIImage(data: data)
                keptRemoteImageURL = nil
                remotePreviewFailed = false
            }
        } catch {
            guard !Task.isCancelled else { return }
            selectedPhotoItem = nil
            selectedImageData = nil
            if keptRemoteImageURL == nil {
                previewImage = nil
            }
            localErrorMessage = "Couldn’t load the selected photo."
        }
    }

    private func submit() async {
        guard !isLoadingPhoto else { return }
        localErrorMessage = nil

        let success: Bool
        if let post = mode.editingPost {
            let removeImage = post.imageURL != nil
                && selectedImageData == nil
                && keptRemoteImageURL == nil
            success = await viewModel.updatePost(
                post,
                text: text,
                image: selectedImageData,
                removeImage: removeImage
            )
        } else {
            success = await viewModel.createPost(text: text, image: selectedImageData)
        }

        if success {
            onDismiss()
        }
    }
}
