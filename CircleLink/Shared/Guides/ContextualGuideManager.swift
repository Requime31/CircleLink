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
    @Published private(set) var presentationGeneration = 0
    private var currentSeries: CLGuideSeries?
    private let defaults: UserDefaults
    private var pendingCompletions: [String: Int] = [:]
    private var persistenceTask: Task<Void, Never>?
    private var sessionGeneration = 0
    private var availableTargets = Set<CLGuideTarget>()
    private var manualSeen = Set<String>()
    private var suspendedAutomaticGuideIDs = Set<String>()

    init(repository: UserRepository, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
    }

    deinit { persistenceTask?.cancel() }

    /// Discard old layout reports whenever navigation or replay changes context.
    func invalidatePresentation() {
        activeTip = nil
        availableTargets = []
        presentationGeneration += 1
    }

    func configure(user: User?) {
        guard user?.id != userID else {
            for (id, version) in user?.contextualGuideCompletions ?? [:] {
                completions[id] = max(completions[id] ?? 0, version)
            }
            reevaluate()
            return
        }
        persistenceTask?.cancel()
        persistenceTask = nil
        sessionGeneration += 1
        userID = user?.id
        completions = user?.contextualGuideCompletions ?? [:]
        pendingCompletions = userID.flatMap {
            defaults.dictionary(forKey: pendingKey(for: $0)) as? [String: Int]
        } ?? [:]
        completions.merge(pendingCompletions, uniquingKeysWith: max)
        currentSeries = nil
        manualSeen = []
        suspendedAutomaticGuideIDs = []
        isBlocked = false
        lastPersistenceError = nil
        mode = .automatic
        invalidatePresentation()
        retryPendingCompletions()
    }

    func visit(_ series: CLGuideSeries) {
        if currentSeries != series {
            currentSeries = series
            invalidatePresentation()
        }
        retryPendingCompletions()
        reevaluate()
    }

    func replay(_ series: CLGuideSeries) {
        mode = .manual(series: series)
        manualSeen = []
        invalidatePresentation()
        reevaluate()
    }

    func updateAvailableTargets(_ targets: Set<CLGuideTarget>, generation: Int? = nil) {
        if let generation, generation != presentationGeneration { return }
        guard targets != availableTargets else { return }
        availableTargets = targets
        if let activeTip, !targets.contains(activeTip.target) { self.activeTip = nil }
        reevaluate()
    }

    func updateBlocked(_ blocked: Bool) {
        guard blocked != isBlocked else { return }
        isBlocked = blocked
        invalidatePresentation()
        if !blocked { retryPendingCompletions() }
    }

    func dismissCurrent() {
        guard let tip = activeTip else { return }
        activeTip = nil
        if case .automatic = mode {
            completions[tip.id] = max(completions[tip.id] ?? 0, tip.version)
            pendingCompletions[tip.id] = max(pendingCompletions[tip.id] ?? 0, tip.version)
            savePendingCompletions()
            retryPendingCompletions()
        } else {
            manualSeen.insert(tip.id)
        }
        reevaluate()
    }

    /// Hands a guide step to a feature-owned flow without marking it complete.
    func suspendCurrent() {
        if case .automatic = mode, let activeTip {
            suspendedAutomaticGuideIDs.insert(activeTip.id)
        }
        activeTip = nil
        availableTargets = []
    }

    /// Makes an abandoned feature-owned guide eligible on the next screen visit.
    func releaseSuspendedGuide(id: String) {
        suspendedAutomaticGuideIDs.remove(id)
    }

    func completeGuide(id: String, version: Int) {
        suspendedAutomaticGuideIDs.remove(id)
        activeTip = nil
        completions[id] = max(completions[id] ?? 0, version)
        pendingCompletions[id] = max(pendingCompletions[id] ?? 0, version)
        savePendingCompletions()
        retryPendingCompletions()
    }

    func finishManualReplay() {
        mode = .automatic
        manualSeen = []
        invalidatePresentation()
    }

    private func reevaluate() {
        guard userID != nil, !isBlocked, activeTip == nil else { return }
        let candidates: [CLGuideTip]
        switch mode {
        case .automatic:
            candidates = CLGuideTip.catalog.filter {
                $0.series == currentSeries
                    && !suspendedAutomaticGuideIDs.contains($0.id)
                    && (completions[$0.id] ?? 0) < $0.version
            }
        case let .manual(series):
            candidates = CLGuideTip.catalog.filter { $0.series == series && !manualSeen.contains($0.id) }
        }
        activeTip = candidates.first { availableTargets.contains($0.target) }
        if case .manual = mode, candidates.isEmpty { finishManualReplay() }
    }

    private func pendingKey(for userID: String) -> String {
        "CircleLink.GuidePending.\(userID)"
    }

    private func savePendingCompletions() {
        guard let userID else { return }
        defaults.set(pendingCompletions, forKey: pendingKey(for: userID))
    }

    /// Serializes writes; failed progress stays durable and retries on the next visit/foreground.
    @discardableResult
    func retryPendingCompletions() -> Task<Void, Never>? {
        guard persistenceTask == nil else { return persistenceTask }
        guard let expectedUserID = userID, !pendingCompletions.isEmpty else { return nil }
        let generation = sessionGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == self.sessionGeneration { self.persistenceTask = nil }
            }
            while !self.pendingCompletions.isEmpty {
                guard !Task.isCancelled, generation == self.sessionGeneration,
                      expectedUserID == self.userID else { return }
                let values = self.pendingCompletions
                do {
                    try await self.repository.completeContextualGuides(values)
                    guard !Task.isCancelled, generation == self.sessionGeneration else { return }
                    for (id, version) in values where (self.pendingCompletions[id] ?? 0) <= version {
                        self.pendingCompletions[id] = nil
                    }
                    self.savePendingCompletions()
                    self.lastPersistenceError = nil
                } catch {
                    guard !Task.isCancelled, generation == self.sessionGeneration else { return }
                    self.lastPersistenceError = error.localizedDescription
                    return
                }
            }
        }
        persistenceTask = task
        return task
    }
}
