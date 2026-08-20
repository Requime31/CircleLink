import Combine
import Foundation
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var aboutMe = ""
    @Published var ageText = ""
    @Published var selectedInterests: Set<String> = []
    @Published private(set) var profile: User?
    @Published private(set) var state: ViewState<User> = .idle
    @Published private(set) var saveState: ViewState<User> = .idle
    @Published private(set) var localAvatarPreview: UIImage?

    @Published private(set) var circlesCount = 0
    @Published private(set) var connectsCount = 0
    @Published private(set) var postsCount = 0
    @Published private(set) var posts: [ProfilePost] = []
    @Published private(set) var isPosting = false
    @Published private(set) var postErrorMessage: String?

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let communityRepository: CommunityRepository
    private let connectionRepository: ConnectionRepository
    private let profilePostRepository: ProfilePostRepository
    private let onProfileSaved: ((User) -> Void)?

    private var pendingAvatarData: Data?
    private var shouldRemoveAvatar = false
    private var statsTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var saveGeneration = 0
    private var sessionGeneration = 0

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        communityRepository: CommunityRepository,
        connectionRepository: ConnectionRepository,
        profilePostRepository: ProfilePostRepository,
        onProfileSaved: ((User) -> Void)? = nil
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.communityRepository = communityRepository
        self.connectionRepository = connectionRepository
        self.profilePostRepository = profilePostRepository
        self.onProfileSaved = onProfileSaved
    }

    var interestCountHint: String {
        "\(selectedInterests.count) of \(User.minInterests)–\(User.maxInterests) selected"
    }

    var canSave: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAge = ageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let ageOk = trimmedAge.isEmpty || Self.parsedAge(from: trimmedAge) != nil
        return !trimmedName.isEmpty
            && selectedInterests.count >= User.minInterests
            && selectedInterests.count <= User.maxInterests
            && ageOk
    }

    var validationMessage: String? {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Enter a display name."
        }
        if selectedInterests.count < User.minInterests {
            return "Select at least \(User.minInterests) interests."
        }
        if selectedInterests.count > User.maxInterests {
            return "Select at most \(User.maxInterests) interests."
        }
        let trimmedAge = ageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAge.isEmpty, Self.parsedAge(from: trimmedAge) == nil {
            return "Enter an age between 18 and 120."
        }
        return nil
    }

    func loadProfile() async {
        guard let userId = authRepository.currentUser?.id else {
            state = .error("Session expired. Please sign in again.")
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        state = .loading
        do {
            let user = try await userRepository.fetchProfile(userId: userId)
            guard generation == loadGeneration,
                  authRepository.currentUser?.id == userId,
                  !Task.isCancelled else { return }
            apply(user: user)
            state = .loaded(user)
            await refreshStatsAndPosts(userId: userId)
        } catch {
            guard generation == loadGeneration, !Task.isCancelled else { return }
            state = .error(error.localizedDescription)
        }
    }

    func refreshStatsAndPosts() async {
        guard let userId = authRepository.currentUser?.id else { return }
        await refreshStatsAndPosts(userId: userId)
    }

    func toggleInterest(_ interest: String) {
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else if selectedInterests.count < User.maxInterests {
            selectedInterests.insert(interest)
        }
    }

    func setAvatarData(_ data: Data) {
        pendingAvatarData = data
        shouldRemoveAvatar = false
        localAvatarPreview = UIImage(data: data)
    }

    func clearAvatarSelection() {
        pendingAvatarData = nil
        localAvatarPreview = nil
        shouldRemoveAvatar = profile?.avatarBase64 != nil || profile?.avatarURL != nil
    }

    var hasAvatarToRemove: Bool {
        localAvatarPreview != nil || profile?.avatarBase64 != nil || profile?.avatarURL != nil
    }

    func saveProfile() async {
        guard saveState != .loading else { return }
        guard canSave else {
            saveState = .error(validationMessage ?? "Complete all required fields.")
            return
        }

        guard var user = profile ?? authRepository.currentUser else {
            saveState = .error("Session expired. Please sign in again.")
            return
        }

        saveGeneration += 1
        let generation = saveGeneration
        saveState = .loading

        do {
            if let avatarData = pendingAvatarData {
                let compressed = try ImageCompressor.compressForAvatar(avatarData)
                user.avatarBase64 = compressed.base64EncodedString()
                user.avatarURL = nil
                pendingAvatarData = nil
            } else if shouldRemoveAvatar {
                user.avatarBase64 = nil
                user.avatarURL = nil
            }

            user.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            user.aboutMe = String(aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
            user.age = Self.parsedAge(from: ageText)
            user.interests = ProfileInterests.presets.filter { selectedInterests.contains($0) }

            try await userRepository.updateProfile(user)
            let refreshed = try await userRepository.fetchProfile(userId: user.id)
            guard generation == saveGeneration,
                  authRepository.currentUser?.id == user.id,
                  !Task.isCancelled else { return }

            apply(user: refreshed)
            saveState = .loaded(refreshed)
            shouldRemoveAvatar = false
            onProfileSaved?(refreshed)
        } catch {
            guard generation == saveGeneration, !Task.isCancelled else { return }
            saveState = .error(error.localizedDescription)
        }
    }

    /// Creates a profile post, then refreshes the list + count.
    @discardableResult
    func createPost(text: String?, image: Data?) async -> Bool {
        guard !isPosting else { return false }
        guard let userId = authRepository.currentUser?.id else {
            postErrorMessage = "Session expired. Please sign in again."
            return false
        }
        let generation = sessionGeneration

        isPosting = true
        postErrorMessage = nil
        defer { isPosting = false }

        do {
            let created = try await profilePostRepository.createPost(
                postId: UUID().uuidString,
                text: text,
                image: image
            )
            guard generation == sessionGeneration,
                  authRepository.currentUser?.id == userId,
                  !Task.isCancelled else { return false }
            // Optimistic local update so a soft-fail refresh cannot hide the new post.
            if !posts.contains(where: { $0.id == created.id }) {
                posts.insert(created, at: 0)
                postsCount += 1
            }
            await refreshStatsAndPosts()
            return true
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return false }
            postErrorMessage = error.localizedDescription
            return false
        }
    }

    /// Updates an existing profile post and patches the local list.
    @discardableResult
    func updatePost(
        _ post: ProfilePost,
        text: String?,
        image: Data?,
        removeImage: Bool
    ) async -> Bool {
        guard !isPosting else { return false }
        guard let userId = authRepository.currentUser?.id else {
            postErrorMessage = "Session expired. Please sign in again."
            return false
        }
        let generation = sessionGeneration

        isPosting = true
        postErrorMessage = nil
        defer { isPosting = false }

        do {
            let updated = try await profilePostRepository.updatePost(
                post,
                text: text,
                image: image,
                removeImage: removeImage
            )
            guard generation == sessionGeneration,
                  authRepository.currentUser?.id == userId,
                  !Task.isCancelled else { return false }
            if let index = posts.firstIndex(where: { $0.id == updated.id }) {
                posts[index] = updated
            }
            await refreshStatsAndPosts()
            return true
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return false }
            postErrorMessage = error.localizedDescription
            return false
        }
    }

    func deletePost(_ post: ProfilePost) async {
        guard !isPosting else { return }
        guard let userId = authRepository.currentUser?.id else { return }
        let generation = sessionGeneration
        isPosting = true
        postErrorMessage = nil
        defer { isPosting = false }
        do {
            try await profilePostRepository.deletePost(post)
            guard generation == sessionGeneration,
                  authRepository.currentUser?.id == userId,
                  !Task.isCancelled else { return }
            posts.removeAll { $0.id == post.id }
            postsCount = max(0, postsCount - 1)
        } catch {
            guard generation == sessionGeneration, !Task.isCancelled else { return }
            postErrorMessage = error.localizedDescription
        }
    }

    func clearPostError() {
        postErrorMessage = nil
    }

    func resetForm() {
        statsTask?.cancel()
        statsTask = nil
        loadGeneration += 1
        saveGeneration += 1
        sessionGeneration += 1
        displayName = ""
        aboutMe = ""
        ageText = ""
        selectedInterests = []
        profile = nil
        state = .idle
        saveState = .idle
        localAvatarPreview = nil
        pendingAvatarData = nil
        shouldRemoveAvatar = false
        circlesCount = 0
        connectsCount = 0
        postsCount = 0
        posts = []
        isPosting = false
        postErrorMessage = nil
    }

    func resetSaveState() {
        saveState = .idle
    }

    /// Compact stats label: `124`, `8.2k`, `1.1M`.
    static func formattedCount(_ value: Int) -> String {
        let absValue = abs(value)
        switch absValue {
        case 1_000_000...:
            let millions = Double(absValue) / 1_000_000
            return String(format: "%gM", (millions * 10).rounded() / 10)
        case 1_000...:
            let thousands = Double(absValue) / 1_000
            return String(format: "%gk", (thousands * 10).rounded() / 10)
        default:
            return "\(value)"
        }
    }

    private func apply(user: User) {
        profile = user
        displayName = user.displayName
        aboutMe = user.aboutMe
        ageText = user.age.map(String.init) ?? ""
        selectedInterests = Set(user.interests)
        if pendingAvatarData == nil {
            localAvatarPreview = nil
        }
    }

    private static func parsedAge(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), (18...120).contains(value) else {
            return nil
        }
        return value
    }

    private func refreshStatsAndPosts(userId: String) async {
        statsTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            async let circles = self.communityRepository.fetchJoinedCommunityCount()
            async let connects = self.connectionRepository.fetchMatchedConnections()
            async let postCount = self.profilePostRepository.fetchPostCount(userId: userId)
            async let latestPosts = self.profilePostRepository.fetchPosts(
                userId: userId,
                limit: 30,
                before: nil
            )

            // Soft-fail per field: keep the previous value when a call fails
            // so a refresh cannot wipe good stats/posts with zeros/empty.
            let nextCircles = try? await circles
            let nextConnects = try? await connects
            let nextPostCount = try? await postCount
            let nextPosts = try? await latestPosts

            guard !Task.isCancelled else { return }
            if let nextCircles {
                self.circlesCount = nextCircles
            }
            if let nextConnects {
                self.connectsCount = nextConnects.count
            }
            if let nextPostCount {
                self.postsCount = nextPostCount
            }
            if let nextPosts {
                self.posts = nextPosts
            }
        }
        statsTask = task
        await task.value
    }
}
