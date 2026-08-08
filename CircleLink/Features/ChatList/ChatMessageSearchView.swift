import Combine
import SwiftUI

/// In-chat message search (client-side filter over paginated history).
@MainActor
final class ChatMessageSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: [Message] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    private let chatId: String
    private let chatRepository: ChatRepository
    private var searchTask: Task<Void, Never>?
    private let pageSize = 50
    private let maxPages = 8
    private var searchGeneration = 0

    init(chatId: String, chatRepository: ChatRepository) {
        self.chatId = chatId
        self.chatRepository = chatRepository
    }

    func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            errorMessage = nil
            return
        }

        searchGeneration += 1
        let generation = searchGeneration
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self, !Task.isCancelled else { return }
            await self.performSearch(term: trimmed, generation: generation)
        }
    }

    func cancel() {
        searchTask?.cancel()
        searchTask = nil
    }

    private func performSearch(term: String, generation: Int) async {
        isSearching = true
        errorMessage = nil
        defer {
            if generation == searchGeneration {
                isSearching = false
            }
        }

        var matches: [Message] = []
        var cursor: Date?
        let lowered = term.lowercased()

        do {
            for _ in 0..<maxPages {
                guard !Task.isCancelled, generation == searchGeneration else { return }
                let page = try await chatRepository.fetchMessages(
                    chatId: chatId,
                    limit: pageSize,
                    before: cursor
                )
                if page.isEmpty { break }

                for message in page.reversed() {
                    guard let text = message.text, !text.isEmpty else { continue }
                    if text.lowercased().contains(lowered) {
                        matches.append(message)
                    }
                }

                cursor = page.first?.createdAt
                if page.count < pageSize { break }
                if matches.count >= 40 { break }
            }
            guard generation == searchGeneration else { return }
            results = matches
        } catch is CancellationError {
            return
        } catch {
            guard generation == searchGeneration else { return }
            errorMessage = error.localizedDescription
            results = []
        }
    }
}

struct ChatMessageSearchView: View {
    @StateObject private var viewModel: ChatMessageSearchViewModel
    @Environment(\.dismiss) private var dismiss
    let onSelectMessage: (Message) -> Void

    init(
        chatId: String,
        chatRepository: ChatRepository,
        onSelectMessage: @escaping (Message) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ChatMessageSearchViewModel(
                chatId: chatId,
                chatRepository: chatRepository
            )
        )
        self.onSelectMessage = onSelectMessage
    }

    var body: some View {
        List {
            Section {
                searchField
                    .listRowBackground(CLColor.surface)
            }

            if viewModel.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(CLColor.primary)
                    Spacer()
                }
                .listRowBackground(CLColor.canvas)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkSecondary)
                    .listRowBackground(CLColor.surface)
            }

            if !viewModel.isSearching,
               viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2,
               viewModel.results.isEmpty,
               viewModel.errorMessage == nil {
                Text("No messages found.")
                    .font(CLTypography.subheadline)
                    .foregroundStyle(CLColor.inkSecondary)
                    .listRowBackground(CLColor.surface)
            }

            ForEach(viewModel.results) { message in
                Button {
                    onSelectMessage(message)
                } label: {
                    VStack(alignment: .leading, spacing: CLSpacing.xxs) {
                        Text(message.text ?? "")
                            .font(CLTypography.body)
                            .foregroundStyle(CLColor.ink)
                            .lineLimit(3)
                        Text(message.createdAt.formatted(ChatListDateFormat.style))
                            .font(CLTypography.caption)
                            .foregroundStyle(CLColor.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(CLColor.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .clCanvasBackground()
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Info")
                    }
                    .foregroundStyle(CLColor.primary)
                }
                .accessibilityLabel("Back to Info")
            }
        }
        .onChange(of: viewModel.query) { _ in
            viewModel.scheduleSearch()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    private var searchField: some View {
        HStack(spacing: CLSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CLColor.inkMuted)
            TextField("Search messages", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundStyle(CLColor.ink)
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.scheduleSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CLColor.inkMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, CLSpacing.xxs)
    }
}
