import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirestoreUserError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case invalidBirthDate
    case sessionChanged
    case accountRecoveryExpired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to access your profile."
        case .profileNotFound:
            return "User profile could not be found."
        case .invalidBirthDate:
            return "Enter a valid birth date for someone aged 18 to 120."
        case .sessionChanged:
            return "Your session changed before the account update completed."
        case .accountRecoveryExpired:
            return "The 30-day account recovery period has ended."
        }
    }
}

final class FirestoreUserRepository: UserRepository, @unchecked Sendable {
    private let usersCollection = "users"
    private let currentUserID: @Sendable () -> String?

    private var db: Firestore { Firestore.firestore() }

    init(currentUserID: @escaping @Sendable () -> String? = { Auth.auth().currentUser?.uid }) {
        self.currentUserID = currentUserID
    }

    func fetchProfile(userId: String) async throws -> User {
        let document = try await db.collection(usersCollection).document(userId).getDocument()

        if document.exists {
            var data = document.data() ?? [:]
            if Auth.auth().currentUser?.uid == userId {
                let privateDocument = try await privateAccountDocument(userId: userId).getDocument()
                if let privateData = privateDocument.data() {
                    data.merge(privateData) { _, privateValue in privateValue }
                }
            }
            return FirestoreUserMapper.user(id: document.documentID, data: data)
        }

        // Bootstrap only the signed-in owner's missing doc (auth/onboarding).
        // Never create a profile when loading another user (peer sheet / Connect).
        guard Auth.auth().currentUser?.uid == userId else {
            throw FirestoreUserError.profileNotFound
        }

        let data = FirestoreUserMapper.defaultProfileData()
        try await db.collection(usersCollection).document(userId).setData(data)
        let created = try await db.collection(usersCollection).document(userId).getDocument()
        return try FirestoreUserMapper.user(from: created)
    }

    func observeProfiles(userIds: Set<String>) -> AsyncThrowingStream<User, Error> {
        let requestedIDs = Array(userIds.filter { !$0.isEmpty })
        guard !requestedIDs.isEmpty else {
            return AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }

        return AsyncThrowingStream { continuation in
            // Firestore `in` queries accept at most 30 comparison values. Keeping the
            // chunks independent also lets screens observe an arbitrary targeted set.
            let idChunks = stride(from: 0, to: requestedIDs.count, by: 30).map { start in
                Array(requestedIDs[start..<min(start + 30, requestedIDs.count)])
            }
            let registrations = ListenerRegistrations()

            continuation.onTermination = { @Sendable _ in
                registrations.terminate()
            }

            for ids in idChunks {
                let registration = db.collection(usersCollection)
                    .whereField(FieldPath.documentID(), in: ids)
                    .addSnapshotListener { snapshot, error in
                        if let error {
                            continuation.finish(throwing: error)
                            registrations.terminate()
                            return
                        }

                        guard let snapshot else { return }
                        for change in snapshot.documentChanges where change.type != .removed {
                            let document = change.document
                            continuation.yield(
                                FirestoreUserMapper.user(id: document.documentID, data: document.data())
                            )
                        }
                    }
                registrations.install(registration)
            }
        }
    }

    func updateProfile(_ user: User) async throws {
        guard Auth.auth().currentUser?.uid == user.id else {
            throw FirestoreUserError.notAuthenticated
        }

        let trimmedAbout = String(user.aboutMe.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))

        var data: [String: Any] = [
            "displayName": user.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            "interests": user.interests,
            "aboutMe": trimmedAbout
        ]

        if let birthDate = user.birthDate {
            let derivedAge = AgeCalculator.completedYears(
                since: birthDate,
                at: Date(),
                calendar: AgeCalculator.persistedCalendar,
                timeZone: AgeCalculator.persistedTimeZone
            )
            if (18...120).contains(derivedAge) {
                data["age"] = derivedAge
            } else {
                data["age"] = NSNull()
            }
        } else if user.ageConfirmedAt != nil, let legacyAge = user.age, (18...120).contains(legacyAge) {
            // Migration-only fallback for confirmed accounts that predate private birthDate storage.
            data["age"] = legacyAge
        }

        if let avatarURL = user.avatarURL?.absoluteString {
            data["avatarURL"] = avatarURL
        } else {
            data["avatarURL"] = NSNull()
        }

        if let avatarBase64 = user.avatarBase64 {
            data["avatarBase64"] = avatarBase64
        } else {
            data["avatarBase64"] = NSNull()
        }

        let document = db.collection(usersCollection).document(user.id)
        let snapshot = try await document.getDocument()

        if snapshot.exists {
            try await document.updateData(data)
        } else {
            var createData = FirestoreUserMapper.defaultProfileData(displayName: user.displayName)
            createData["displayName"] = data["displayName"] as Any
            createData["interests"] = data["interests"] as Any
            createData["aboutMe"] = data["aboutMe"] as Any
            if let derivedAge = data["age"] {
                createData["age"] = derivedAge
            }
            createData["avatarURL"] = data["avatarURL"] as Any
            createData["avatarBase64"] = data["avatarBase64"] as Any
            try await document.setData(createData)
        }
    }

    func confirmAge() async throws {
        guard currentUserID() != nil else {
            throw FirestoreUserError.notAuthenticated
        }
        // Confirmation must atomically persist the private birth date. The
        // legacy no-argument API cannot satisfy that security invariant.
        throw FirestoreUserError.invalidBirthDate
    }

    func confirmAge(birthDate localBirthDate: Date) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreUserError.notAuthenticated
        }

        guard let canonicalBirthDate = AgeCalculator.canonicalBirthDate(fromLocalDate: localBirthDate) else {
            throw FirestoreUserError.invalidBirthDate
        }

        let confirmedAt = Date()
        guard let canonicalToday = AgeCalculator.canonicalBirthDate(fromLocalDate: confirmedAt) else {
            throw FirestoreUserError.invalidBirthDate
        }
        let age = AgeCalculator.completedYears(
            since: canonicalBirthDate,
            at: canonicalToday,
            calendar: AgeCalculator.persistedCalendar,
            timeZone: AgeCalculator.persistedTimeZone
        )
        guard (18...120).contains(age) else {
            throw FirestoreUserError.invalidBirthDate
        }

        let data = FirestoreUserMapper.ageConfirmationData(
            birthDate: canonicalBirthDate,
            confirmedAt: confirmedAt,
            ageReferenceDate: canonicalToday,
            calendar: AgeCalculator.persistedCalendar,
            timeZone: AgeCalculator.persistedTimeZone
        )
        let publicDocument = db.collection(usersCollection).document(userId)
        let batch = db.batch()
        batch.updateData(data.publicProfile, forDocument: publicDocument)
        batch.setData(data.privateAccount, forDocument: privateAccountDocument(userId: userId), merge: true)
        try await batch.commit()
    }

    func requestAccountDeletion(now: Date) async throws {
        guard let userId = currentUserID() else {
            throw FirestoreUserError.notAuthenticated
        }
        try await ensureRecentAuthentication()
        let document = db.collection(usersCollection).document(userId)
        let privateDocument = privateAccountDocument(userId: userId)
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(document)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
                guard snapshot.exists else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreUserRepository",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: FirestoreUserError.profileNotFound.localizedDescription]
                    )
                    return nil
                }
                let state = AccountState(rawValue: snapshot.data()?["accountState"] as? String ?? "") ?? .active
                guard state != .deactivated else { return nil }
                guard self.currentUserID() == userId else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreUserRepository.SessionChanged",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: FirestoreUserError.sessionChanged.localizedDescription]
                    )
                    return nil
                }
                transaction.updateData(
                    ["accountState": AccountState.deactivated.rawValue],
                    forDocument: document
                )
                transaction.setData(
                    [
                        "accountState": AccountState.deactivated.rawValue,
                        "deletionRequestedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: privateDocument,
                    merge: true
                )
                return nil
            }
        } catch let error as NSError where error.domain == "FirestoreUserRepository.SessionChanged" {
            throw FirestoreUserError.sessionChanged
        } catch let error as NSError where error.domain == "FirestoreUserRepository" && error.code == 404 {
            throw FirestoreUserError.profileNotFound
        } catch let error as NSError where error.domain == AuthErrorDomain
            && error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            throw AccountLifecycleError.requiresRecentLogin
        }
    }

    func restoreAccount() async throws {
        guard let userId = currentUserID() else {
            throw FirestoreUserError.notAuthenticated
        }
        let document = db.collection(usersCollection).document(userId)
        let privateDocument = privateAccountDocument(userId: userId)
        do {
            _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(document)
                    let privateSnapshot = try transaction.getDocument(privateDocument)
                    guard snapshot.exists else {
                        throw NSError(domain: "FirestoreUserRepository", code: 404)
                    }
                    guard self.currentUserID() == userId else {
                        throw NSError(domain: "FirestoreUserRepository.SessionChanged", code: 409)
                    }
                    guard let requestedAt = (privateSnapshot.data()?["deletionRequestedAt"] as? Timestamp)?.dateValue(),
                          let deadline = AccountDeletionPolicy.scheduledDeletionDate(from: requestedAt),
                          Date() < deadline else {
                        throw NSError(domain: "FirestoreUserRepository.RecoveryExpired", code: 410)
                    }
                    transaction.updateData([
                        "accountState": AccountState.active.rawValue
                    ], forDocument: document)
                    transaction.setData([
                        "accountState": FieldValue.delete(),
                        "deletionRequestedAt": FieldValue.delete()
                    ], forDocument: privateDocument, merge: true)
                } catch {
                    errorPointer?.pointee = error as NSError
                }
                return nil
            }
        } catch let error as NSError where error.domain == "FirestoreUserRepository.SessionChanged" {
            throw FirestoreUserError.sessionChanged
        } catch let error as NSError where error.domain == "FirestoreUserRepository.RecoveryExpired" {
            throw FirestoreUserError.accountRecoveryExpired
        }
    }

    func updateFCMToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreUserError.notAuthenticated
        }

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await privateAccountDocument(userId: userId).setData(
            [
                "fcmToken": trimmed,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    func clearFCMToken() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreUserError.notAuthenticated
        }

        try await privateAccountDocument(userId: userId).setData(
            [
                "fcmToken": FieldValue.delete(),
                "fcmTokenUpdatedAt": FieldValue.delete()
            ],
            merge: true
        )
    }

    private func privateAccountDocument(userId: String) -> DocumentReference {
        db.collection(usersCollection)
            .document(userId)
            .collection("private")
            .document("account")
    }

    private func ensureRecentAuthentication() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw FirestoreUserError.notAuthenticated
        }
        let token = try await currentUser.getIDTokenResult(forcingRefresh: false)
        guard Date().timeIntervalSince(token.authDate) <= 5 * 60 else {
            throw AccountLifecycleError.requiresRecentLogin
        }
    }
}

/// Listener installation can race with stream cancellation. This box guarantees that a
/// registration installed after termination is removed immediately and never leaked.
nonisolated private final class ListenerRegistrations: @unchecked Sendable {
    private let lock = NSLock()
    private var registrations: [ListenerRegistration] = []
    private var isTerminated = false

    func install(_ registration: ListenerRegistration) {
        lock.lock()
        guard !isTerminated else {
            lock.unlock()
            registration.remove()
            return
        }
        registrations.append(registration)
        lock.unlock()
    }

    func terminate() {
        lock.lock()
        guard !isTerminated else {
            lock.unlock()
            return
        }
        isTerminated = true
        let registrations = self.registrations
        self.registrations.removeAll()
        lock.unlock()
        registrations.forEach { $0.remove() }
    }
}
