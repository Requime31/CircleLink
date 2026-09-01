import PhotosUI
import SwiftUI
import UIKit

struct CommunityComposePostSheet: View {
    @ObservedObject var viewModel: CommunityDetailViewModel
    let post: CommunityPost?
    let onDismiss: () -> Void

    @State private var text = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var preview: UIImage?
    @State private var keptRemoteImageURL: URL?
    @State private var remotePreviewFailed = false
    @State private var localErrorMessage: String?
    @State private var isLoading = false
    @State private var didPrefill = false
    @State private var photoLoadGeneration = 0
    @FocusState private var isFocused: Bool

    private var isEditing: Bool { post != nil }

    private var canSubmit: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || imageData != nil
            || keptRemoteImageURL != nil)
            && !viewModel.isPosting && !isLoading
    }

    private var showsPhotoChrome: Bool {
        preview != nil || (keptRemoteImageURL != nil && remotePreviewFailed)
    }

    private var previewHeight: CGFloat { isEditing ? 180 : 220 }

    private var bannerError: String? {
        localErrorMessage ?? viewModel.postErrorMessage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    TextField("Share with the community…", text: $text, axis: .vertical)
                        .lineLimit(4 ... 12)
                        .focused($isFocused)
                        .clTextFieldChrome(isFocused: isFocused)

                    photoSection

                    if let error = bannerError {
                        Text(error)
                            .font(CLTypography.footnote)
                            .foregroundStyle(CLColor.error)
                            .padding(CLSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CLColor.errorSoft)
                            .clipShape(RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous))
                            .accessibilityLabel("Post error: \(error)")
                    }

                    if !isEditing {
                        Button { Task { await submit() } } label: {
                            submitLabel(title: "Post")
                        }
                        .buttonStyle(CLPrimaryButtonStyle())
                        .disabled(!canSubmit)
                        .accessibilityLabel("Publish community post")
                    }
                }
                .padding(CLSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .clCanvasBackground()
            .navigationTitle(isEditing ? "Edit Post" : "New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        photoLoadGeneration += 1
                        viewModel.clearPostError()
                        onDismiss()
                    }
                    .disabled(viewModel.isPosting)
                }
                if isEditing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await submit() }
                        } label: {
                            if viewModel.isPosting {
                                ProgressView()
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(!canSubmit)
                        .accessibilityLabel("Save post")
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isPosting)
            .task { await prefill() }
            .onChange(of: photoItem) { item in Task { await load(item) } }
            .onDisappear { photoLoadGeneration += 1 }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            if showsPhotoChrome {
                photoPreview

                HStack(spacing: CLSpacing.sm) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text(isEditing ? "Replace Photo" : "Change Photo")
                            .font(CLTypography.button)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    }
                    .buttonStyle(CLSecondaryButtonStyle())
                    .disabled(isLoading || viewModel.isPosting)
                    .accessibilityLabel(isEditing ? "Replace post photo" : "Change post photo")

                    Button("Remove Photo") { removeImage() }
                        .buttonStyle(CLSecondaryButtonStyle())
                        .disabled(isLoading || viewModel.isPosting)
                        .accessibilityLabel("Remove post photo")
                }
            } else if isLoading {
                ZStack {
                    CLColor.surfaceSoft
                    ProgressView().tint(CLColor.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                .accessibilityLabel("Loading photo")
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
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
        if let preview {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: previewHeight)
                .clipped()
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
            .frame(height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
            .accessibilityLabel("Could not load photo")
        }
    }

    private func prefill() async {
        guard !didPrefill, let post else { return }
        didPrefill = true
        text = post.text ?? ""
        keptRemoteImageURL = post.imageURL
        guard let url = post.imageURL else { return }

        photoLoadGeneration += 1
        let generation = photoLoadGeneration
        isLoading = true
        defer {
            if generation == photoLoadGeneration { isLoading = false }
        }

        do {
            let loaded = try await ImageLoader.shared.load(from: url)
            guard generation == photoLoadGeneration,
                  keptRemoteImageURL == url,
                  !Task.isCancelled else { return }
            preview = loaded
            remotePreviewFailed = loaded == nil
        } catch {
            guard generation == photoLoadGeneration,
                  keptRemoteImageURL == url,
                  !Task.isCancelled else { return }
            preview = nil
            remotePreviewFailed = true
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        photoLoadGeneration += 1
        let generation = photoLoadGeneration
        localErrorMessage = nil
        isLoading = true
        defer {
            if generation == photoLoadGeneration { isLoading = false }
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                guard generation == photoLoadGeneration, !Task.isCancelled else { return }
                localErrorMessage = "Couldn’t load the selected photo."
                photoItem = nil
                return
            }
            guard generation == photoLoadGeneration, !Task.isCancelled else { return }
            imageData = data
            preview = UIImage(data: data)
            keptRemoteImageURL = nil
            remotePreviewFailed = false
        } catch {
            guard generation == photoLoadGeneration, !Task.isCancelled else { return }
            photoItem = nil
            imageData = nil
            if keptRemoteImageURL == nil { preview = nil }
            localErrorMessage = "Couldn’t load the selected photo."
        }
    }

    private func removeImage() {
        photoLoadGeneration += 1
        photoItem = nil
        imageData = nil
        preview = nil
        keptRemoteImageURL = nil
        remotePreviewFailed = false
        isLoading = false
        localErrorMessage = nil
    }

    private func submit() async {
        let success: Bool
        if let post {
            let removeImage = post.imageURL != nil
                && imageData == nil
                && keptRemoteImageURL == nil
            success = await viewModel.updatePost(
                post,
                text: text,
                image: imageData,
                removeImage: removeImage
            )
        } else {
            success = await viewModel.createPost(text: text, image: imageData)
        }
        if success { onDismiss() }
    }

    @ViewBuilder
    private func submitLabel(title: String) -> some View {
        if viewModel.isPosting {
            ProgressView().tint(CLColor.onPrimary)
        } else {
            Text(title)
        }
    }
}
