import PhotosUI
import SwiftUI
import UIKit

/// Compose sheet: text and/or one photo. Empty both is blocked.
struct ComposeCommunityPostSheet: View {
    @ObservedObject var feedViewModel: CommunityFeedViewModel
    let onDismiss: () -> Void

    @State private var text = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var previewImage: UIImage?
    @FocusState private var isTextFocused: Bool

    private var canPost: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || selectedImageData != nil) && !feedViewModel.isPosting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CLSpacing.lg) {
                    TextField(
                        "Share something with the community…",
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

                    if let errorMessage = feedViewModel.errorMessage {
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
                        if feedViewModel.isPosting {
                            ProgressView()
                                .tint(CLColor.onPrimary)
                        } else {
                            Text("Post")
                        }
                    }
                    .buttonStyle(CLPrimaryButtonStyle())
                    .disabled(!canPost)
                    .accessibilityLabel("Publish post")
                }
                .padding(CLSpacing.md)
            }
            .clCanvasBackground()
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        feedViewModel.clearError()
                        onDismiss()
                    }
                    .disabled(feedViewModel.isPosting)
                }
            }
            .interactiveDismissDisabled(feedViewModel.isPosting)
            .onAppear {
                isTextFocused = true
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: CLSpacing.sm) {
            if let preview = previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: CLRadius.md, style: .continuous))
                    .accessibilityLabel("Selected photo preview")

                HStack(spacing: CLSpacing.sm) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("Change Photo")
                            .font(CLTypography.button)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                    }
                    .buttonStyle(CLSecondaryButtonStyle())
                    .accessibilityLabel("Change post photo")

                    Button("Remove") {
                        selectedPhotoItem = nil
                        selectedImageData = nil
                        previewImage = nil
                    }
                    .buttonStyle(CLSecondaryButtonStyle())
                    .accessibilityLabel("Remove post photo")
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add Photo", systemImage: "photo")
                        .font(CLTypography.button)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AccessibilityHelpers.minimumTouchTarget)
                }
                .buttonStyle(CLSecondaryButtonStyle())
                .accessibilityLabel("Add photo to post")
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task { @MainActor in
                await loadPhoto(from: newItem)
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        selectedImageData = data
        previewImage = UIImage(data: data)
    }

    private func submit() async {
        feedViewModel.clearError()
        let ok = await feedViewModel.createPost(
            text: text,
            imageData: selectedImageData
        )
        if ok {
            onDismiss()
        }
    }
}
