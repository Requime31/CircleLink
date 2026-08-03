import Foundation

/// Firestore document shape for `users/{userId}` fields that map into Domain `User`.
///
/// Data-layer only — Features should not decode these keys directly.
/// Wire format is unchanged (Spark plan):
/// - `displayName`: String
/// - `avatarURL`: String | null
/// - `avatarBase64`: String | null — compressed JPEG stored in the document
/// - `interests`: [String]
/// - `ageConfirmedAt`: Timestamp | null
///
/// Not part of this DTO (written separately): `fcmToken`, `fcmTokenUpdatedAt`, `createdAt`.
struct FirestoreUserDocument: Equatable, Sendable {
    var displayName: String
    /// Firestore stores URLs as strings.
    var avatarURLString: String?
    /// Storage-specific field mirrored onto Domain `User.avatarBase64` for now.
    var avatarBase64: String?
    var interests: [String]
    var ageConfirmedAt: Date?
}
