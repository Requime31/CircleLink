import Combine
import Foundation

@MainActor
final class ContextualGuideManager: ObservableObject {
    @Published private(set) var activeTip: CLGuideTip?
    @Published private(set) var mode: CLGuidePresentationMode = .automatic
    @Published private(set) var isBlocked = false
    @Published private(set) var lastPersistenceError: String?

    private let repository: UserRepository
    private var userID: String?
    private var completions: [String: Int] = [:]
    private var visitedSeries = Set<CLGuideSeries>()
    private var availableTargets = Set<CLGuideTarget>()
    private var manualSeen = Set<String>()

    init(repository: UserRepository) { self.repository = repository }

    func configure(user: User?) {
        guard user?.id != userID else {
            for (id, version) in user?.contextualGuideCompletions ?? [:] {
                completions[id] = max(completions[id] ?? 0, version)
            }
            reevaluate()
            return
        }
        userID = user?.id
        completions = user?.contextualGuideCompletions ?? [:]
        visitedSeries = []
        activeTip = nil
        mode = .automatic
    }

    func visit(_ series: CLGuideSeries) {
        visitedSeries.insert(series)
        reevaluate()
    }

    func replay(_ series: CLGuideSeries) {
        mode = .manual(series: series)
        manualSeen = []
        activeTip = nil
        visitedSeries.insert(series)
        reevaluate()
    }

    func updateAvailableTargets(_ targets: Set<CLGuideTarget>) {
        guard targets != availableTargets else { return }
        availableTargets = targets
        if let activeTip, !targets.contains(activeTip.target) { self.activeTip = nil }
        reevaluate()
    }

    func updateBlocked(_ blocked: Bool) {
        guard blocked != isBlocked else { return }
        isBlocked = blocked
        if blocked { activeTip = nil }
        else { reevaluate() }
    }

    func dismissCurrent() {
        guard let tip = activeTip else { return }
        activeTip = nil
        if case .automatic = mode {
            completions[tip.id] = max(completions[tip.id] ?? 0, tip.version)
            persist([tip.id: tip.version])
        } else {
            manualSeen.insert(tip.id)
        }
        reevaluate()
    }

    func finishManualReplay() {
        activeTip = nil
        mode = .automatic
        manualSeen = []
    }

    private func reevaluate() {
        guard !isBlocked, activeTip == nil else { return }
        let candidates: [CLGuideTip]
        switch mode {
        case .automatic:
            candidates = CLGuideTip.catalog.filter {
                visitedSeries.contains($0.series) && (completions[$0.id] ?? 0) < $0.version
            }
        case let .manual(series):
            candidates = CLGuideTip.catalog.filter { $0.series == series && !manualSeen.contains($0.id) }
        }
        activeTip = candidates.first { availableTargets.contains($0.target) }
        if case .manual = mode, candidates.isEmpty { finishManualReplay() }
    }

    private func persist(_ values: [String: Int]) {
        let expectedUserID = userID
        Task {
            do {
                try await repository.completeContextualGuides(values)
                guard expectedUserID == userID else { return }
                lastPersistenceError = nil
            } catch {
                guard expectedUserID == userID else { return }
                lastPersistenceError = error.localizedDescription
            }
        }
    }
}
