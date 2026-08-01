import Foundation

/// Parsed remote-notification payload for AppCoordinator routing.
struct PushDeepLink: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case newMessage = "new_message"
        case connectionRequest = "connection_request"
        case connectionAccepted = "connection_accepted"
    }

    enum Tab: String, Equatable, Sendable {
        case chats
        case connect
    }

    let kind: Kind
    let chatId: String?
    let requestId: String?
    let tab: Tab?
    /// Intended recipient — discard if it does not match the signed-in user.
    let targetUserId: String?

    init(
        kind: Kind,
        chatId: String? = nil,
        requestId: String? = nil,
        tab: Tab? = nil,
        targetUserId: String? = nil
    ) {
        self.kind = kind
        self.chatId = chatId
        self.requestId = requestId
        self.tab = tab
        self.targetUserId = targetUserId
    }

    /// Builds a deep link from FCM / APNs `userInfo`.
    /// Returns `nil` when `type` is missing or unknown.
    static func parse(userInfo: [AnyHashable: Any]) -> Self? {
        let payload = Self.flattenedPayload(from: userInfo)

        guard let typeRaw = payload["type"], let kind = Kind(rawValue: typeRaw) else {
            return nil
        }

        let chatId = Self.nonEmpty(payload["chatId"])
        let requestId = Self.nonEmpty(payload["requestId"])
        let tab = Self.nonEmpty(payload["tab"]).flatMap(Tab.init(rawValue:))
        let targetUserId = Self.nonEmpty(payload["targetUserId"])

        return Self(
            kind: kind,
            chatId: chatId,
            requestId: requestId,
            tab: tab,
            targetUserId: targetUserId
        )
    }

    private static func flattenedPayload(from userInfo: [AnyHashable: Any]) -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in userInfo {
            guard let key = key as? String else { continue }

            if let string = value as? String {
                result[key] = string
            } else if let number = value as? NSNumber {
                result[key] = number.stringValue
            } else if let nested = value as? [String: Any] {
                // FCM sometimes nests custom data; flatten one level.
                for (nestedKey, nestedValue) in nested {
                    if let string = nestedValue as? String {
                        result[nestedKey] = string
                    } else if let number = nestedValue as? NSNumber {
                        result[nestedKey] = number.stringValue
                    }
                }
            }
        }

        return result
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
