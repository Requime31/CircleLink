import Combine
import Foundation
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var selectedInterests: Set<String> = []
    @Published private(set) var profile: User?
    @Published private(set) var state: ViewState<User> = .idle
    @Published private(set) var saveState: ViewState<User> = .idle
    @Published private(set) var localAvatarPreview: UIImage?

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let onProfileSaved: ((User) -> Void)?

    private var pendingAvatarData: Data?
    private var shouldRemoveAvatar = false

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        onProfileSaved: ((User) -> Void)? = nil
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.onProfileSaved = onProfileSaved
    }

    var interestCountHint: String {
        "\(selectedInterests.count) of \(User.minInterests)–\(User.maxInterests) selected"
    }

    var canSave: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
            && selectedInterests.count >= User.minInterests
            && selectedInterests.count <= User.maxInterests
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
        return nil
    }

    func loadProfile() async {
        guard let userId = authRepository.currentUser?.id else {
            state = .error("Session expired. Please sign in again.")
            return
        }

        state = .loading
        do {
            let user = try await userRepository.fetchProfile(userId: userId)
            apply(user: user)
            state = .loaded(user)
        } catch {
            state = .error(error.localizedDescription)
        }
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
        guard canSave else {
            saveState = .error(validationMessage ?? "Complete all required fields.")
            return
        }

        guard var user = profile ?? authRepository.currentUser else {
            saveState = .error("Session expired. Please sign in again.")
            return
        }

        saveState = .loading

        do {
            if let avatarData = pendingAvatarData {
                // Avatar is stored as base64 on User — compress once, off MainActor.
                let compressed = try await ImageCompressor.compressForAvatarOffMain(avatarData)
                user.avatarBase64 = compressed.base64EncodedString()
                user.avatarURL = nil
                pendingAvatarData = nil
            } else if shouldRemoveAvatar {
                user.avatarBase64 = nil
                user.avatarURL = nil
            }

            user.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            user.interests = ProfileInterests.presets.filter { selectedInterests.contains($0) }

            try await userRepository.updateProfile(user)
            let refreshed = try await userRepository.fetchProfile(userId: user.id)

            apply(user: refreshed)
            saveState = .loaded(refreshed)
            shouldRemoveAvatar = false
            onProfileSaved?(refreshed)
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }

    func resetForm() {
        displayName = ""
        selectedInterests = []
        profile = nil
        state = .idle
        saveState = .idle
        localAvatarPreview = nil
        pendingAvatarData = nil
        shouldRemoveAvatar = false
    }

    func resetSaveState() {
        saveState = .idle
    }

    private func apply(user: User) {
        profile = user
        displayName = user.displayName
        selectedInterests = Set(user.interests)
        if pendingAvatarData == nil {
            localAvatarPreview = nil
        }
    }
}
