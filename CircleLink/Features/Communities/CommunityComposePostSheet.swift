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
    @State private var keepsExistingImage = false
    @State private var isLoading = false
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData != nil || keepsExistingImage)
            && !viewModel.isPosting && !isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    TextField("Share with the community…", text: $text, axis: .vertical)
                        .lineLimit(4 ... 12)
                        .focused($isFocused)
                        .clTextFieldChrome(isFocused: isFocused)

                    if let preview {
                        Image(uiImage: preview).resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    }

                    HStack(spacing: CLSpacing.sm) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(preview == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CLSecondaryButtonStyle())
                        if preview != nil || keepsExistingImage {
                            Button("Remove") { removeImage() }
                                .buttonStyle(CLSecondaryButtonStyle())
                        }
                    }

                    if let error = viewModel.postErrorMessage {
                        Text(error).font(CLTypography.footnote).foregroundStyle(CLColor.error)
                    }

                    Button { Task { await submit() } } label: {
                        if viewModel.isPosting { ProgressView().tint(CLColor.onPrimary) }
                        else { Text(post == nil ? "Post" : "Save") }
                    }
                    .buttonStyle(CLPrimaryButtonStyle())
                    .disabled(!canSubmit)
                }
                .padding(CLSpacing.md)
            }
            .clCanvasBackground()
            .navigationTitle(post == nil ? "New Post" : "Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss) } }
            .task { await prefill() }
            .onChange(of: photoItem) { item in Task { await load(item) } }
        }
    }

    private func prefill() async {
        guard let post else { return }
        text = post.text ?? ""
        keepsExistingImage = post.imageURL != nil
        if let url = post.imageURL { preview = try? await ImageLoader.shared.load(from: url) }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoading = true; defer { isLoading = false }
        if let data = try? await item.loadTransferable(type: Data.self) {
            imageData = data; preview = UIImage(data: data); keepsExistingImage = false
        }
    }

    private func removeImage() { photoItem = nil; imageData = nil; preview = nil; keepsExistingImage = false }

    private func submit() async {
        let success: Bool
        if let post {
            success = await viewModel.updatePost(post, text: text, image: imageData, removeImage: post.imageURL != nil && imageData == nil && !keepsExistingImage)
        } else {
            success = await viewModel.createPost(text: text, image: imageData)
        }
        if success { onDismiss() }
    }
}
