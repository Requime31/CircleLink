import Combine
import SwiftUI

/// Full shared-media grid for a chat.
@MainActor
final class ChatMediaGalleryViewModel: ObservableObject {
    @Published private(set) var items: [Message] = []
    @Published private(set) var isLoading = false
    @Published private(set) var canLoadMore = true
    @Published private(set) var errorMessage: String?

    private let chatId: String
    private let chatRepository: ChatRepository
    private let pageSize = 40
    private var isLoadingMore = false

    init(chatId: String, chatRepository: ChatRepository) {
        self.chatId = chatId
        self.chatRepository = chatRepository
    }

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await chatRepository.fetchChatMedia(
                chatId: chatId,
                limit: pageSize,
                before: nil
            )
            items = fetched
            canLoadMore = fetched.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(currentItem: Message) async {
        guard canLoadMore, !isLoadingMore else { return }
        guard let last = items.last, last.id == currentItem.id else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let fetched = try await chatRepository.fetchChatMedia(
                chatId: chatId,
                limit: pageSize,
                before: last.createdAt
            )
            let known = Set(items.map(\.id))
            let unique = fetched.filter { !known.contains($0.id) }
            items.append(contentsOf: unique)
            canLoadMore = fetched.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ChatMediaGalleryView: View {
    @StateObject private var viewModel: ChatMediaGalleryViewModel
    @State private var presentedMedia: IdentifiedURL?

    init(chatId: String, chatRepository: ChatRepository) {
        _viewModel = StateObject(
            wrappedValue: ChatMediaGalleryViewModel(
                chatId: chatId,
                chatRepository: chatRepository
            )
        )
    }

    private let columns = [
        GridItem(.flexible(), spacing: CLSpacing.xs),
        GridItem(.flexible(), spacing: CLSpacing.xs),
        GridItem(.flexible(), spacing: CLSpacing.xs),
        GridItem(.flexible(), spacing: CLSpacing.xs)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("Loading…")
                    .tint(CLColor.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                VStack(spacing: CLSpacing.sm) {
                    Text(errorMessage)
                        .font(CLTypography.body)
                        .foregroundStyle(CLColor.inkSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.loadInitial() }
                    }
                    .buttonStyle(CLSecondaryButtonStyle())
                }
                .padding(CLSpacing.lg)
            } else if viewModel.items.isEmpty {
                Text("No shared media yet.")
                    .font(CLTypography.body)
                    .foregroundStyle(CLColor.inkSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: CLSpacing.xs) {
                        ForEach(viewModel.items) { message in
                            if let url = message.imageURL {
                                Button {
                                    presentedMedia = IdentifiedURL(url)
                                } label: {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case let .success(image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            CLColor.surfaceSoft
                                        }
                                    }
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CLRadius.sm, style: .continuous)
                                            .stroke(CLColor.hairline, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .task {
                                    await viewModel.loadMoreIfNeeded(currentItem: message)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, CLSpacing.screenHorizontal)
                    .padding(.vertical, CLSpacing.md)
                }
            }
        }
        .clCanvasBackground()
        .navigationTitle("Shared Media")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadInitial()
        }
        .fullScreenCover(item: $presentedMedia) { item in
            ChatMediaFullscreenView(url: item.url)
        }
    }
}

private struct IdentifiedURL: Identifiable {
    let id: String
    let url: URL

    init(_ url: URL) {
        self.url = url
        self.id = url.absoluteString
    }
}

private struct ChatMediaFullscreenView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(CLSpacing.md)
            }
            .accessibilityLabel("Close")
        }
    }
}
