import Combine
import Foundation

struct BlockedPersonRow: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let avatarURL: URL?
    let avatarBase64: String?
    let isFallback: Bool

    nonisolated static func fallback(id: String) -> Self {
        Self(
            id: id,
            displayName: "Unavailable account",
            avatarURL: nil,
            avatarBase64: nil,
            isFallback: true
        )
    }
}

@MainActor
final class BlockedPeopleViewModel: ObservableObject {
    @Published private(set) var state: ViewState<[BlockedPersonRow]> = .idle
    @Published private(set) var unblockingIDs: Set<String> = []
    @Published private(set) var actionErrorMessage: String?

    private let moderationRepository: ModerationRepository
    private let userRepository: UserRepository
    private var generation = 0

    init(
        moderationRepository: ModerationRepository,
        userRepository: UserRepository
    ) {
        self.moderationRepository = moderationRepository
        self.userRepository = userRepository
    }

    func load() async {
        generation += 1
        let currentGeneration = generation
        state = .loading
        actionErrorMessage = nil

        do {
            let ids = try await moderationRepository.fetchBlockedUserIds().sorted()
            try Task.checkCancellation()
            guard currentGeneration == generation else { return }
            guard !ids.isEmpty else {
                state = .empty
                return
            }

            let rows = try await Self.resolveRows(
                ids: ids,
                userRepository: userRepository
            )
            try Task.checkCancellation()
            guard currentGeneration == generation else { return }
            state = rows.isEmpty ? .empty : .loaded(rows)
        } catch is CancellationError {
            // A replaced/disappeared load must not overwrite newer state.
        } catch {
            guard currentGeneration == generation else { return }
            state = .error(error.localizedDescription)
        }
    }

    @discardableResult
    func unblock(_ row: BlockedPersonRow) async -> Bool {
        guard !unblockingIDs.contains(row.id),
              case let .loaded(currentRows) = state,
              let originalIndex = currentRows.firstIndex(where: { $0.id == row.id })
        else { return false }

        let currentGeneration = generation
        unblockingIDs.insert(row.id)
        actionErrorMessage = nil
        var optimisticRows = currentRows
        optimisticRows.remove(at: originalIndex)
        state = optimisticRows.isEmpty ? .empty : .loaded(optimisticRows)

        defer {
            if currentGeneration == generation {
                unblockingIDs.remove(row.id)
            }
        }

        do {
            try await moderationRepository.unblockUser(row.id)
            guard currentGeneration == generation, !Task.isCancelled else { return false }
            return true
        } catch {
            guard currentGeneration == generation, !Task.isCancelled else { return false }
            var restoredRows: [BlockedPersonRow]
            switch state {
            case let .loaded(rows): restoredRows = rows
            case .empty: restoredRows = []
            default: restoredRows = optimisticRows
            }
            guard !restoredRows.contains(where: { $0.id == row.id }) else { return false }
            restoredRows.insert(row, at: min(originalIndex, restoredRows.count))
            state = .loaded(restoredRows)
            actionErrorMessage = error.localizedDescription
            return false
        }
    }

    func clearActionError() {
        actionErrorMessage = nil
    }

    func reset() {
        generation += 1
        state = .idle
        unblockingIDs = []
        actionErrorMessage = nil
    }

    nonisolated private static func resolveRows(
        ids: [String],
        userRepository: UserRepository
    ) async throws -> [BlockedPersonRow] {
        var resolved: [BlockedPersonRow] = []
        resolved.reserveCapacity(ids.count)
        let profileBatchSize = 4

        for batchStart in stride(from: 0, to: ids.count, by: profileBatchSize) {
            try Task.checkCancellation()
            let batchEnd = min(batchStart + profileBatchSize, ids.count)
            let batch = Array(ids[batchStart..<batchEnd])

            let rows = await withTaskGroup(of: BlockedPersonRow.self) { group in
                for id in batch {
                    group.addTask {
                        guard !Task.isCancelled else { return .fallback(id: id) }
                        do {
                            let user = try await userRepository.fetchProfile(userId: id)
                            guard user.accountState == .active else { return .fallback(id: id) }
                            let name = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return .fallback(id: id) }
                            return BlockedPersonRow(
                                id: id,
                                displayName: name,
                                avatarURL: user.avatarURL,
                                avatarBase64: user.avatarBase64,
                                isFallback: false
                            )
                        } catch {
                            return .fallback(id: id)
                        }
                    }
                }

                var batchRows: [BlockedPersonRow] = []
                for await row in group { batchRows.append(row) }
                return batchRows
            }
            resolved.append(contentsOf: rows)
        }

        try Task.checkCancellation()
        return resolved.sorted { lhs, rhs in
            if lhs.isFallback != rhs.isFallback { return !lhs.isFallback }
            let comparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return lhs.id < rhs.id
        }
    }
}
