import Foundation
import MessageUI
import StoreKit
import UIKit

enum CircleLinkAppConfiguration {
    /// Replace and set `supportEmailIsPlaceholder` to false before release.
    static let supportEmail = "support@circlelink.app"
    static let supportEmailIsPlaceholder = true
}

struct SupportMailPayload: Equatable, Sendable {
    let recipient: String
    let subject: String
    let body: String

    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

struct SupportDeviceMetadata: Equatable, Sendable {
    let version: String
    let build: String
    let iOSVersion: String
    let deviceModel: String
}

@MainActor
protocol SupportDeviceMetadataProviding {
    var metadata: SupportDeviceMetadata { get }
}

@MainActor
struct SystemSupportDeviceMetadataProvider: SupportDeviceMetadataProviding {
    var metadata: SupportDeviceMetadata {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return SupportDeviceMetadata(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            iOSVersion: UIDevice.current.systemVersion,
            deviceModel: model
        )
    }
}

enum SupportMailPayloadFactory {
    static func make(
        recipient: String = CircleLinkAppConfiguration.supportEmail,
        metadata: SupportDeviceMetadata
    ) -> SupportMailPayload {
        SupportMailPayload(
            recipient: recipient,
            subject: "CircleLink Support",
            body: """
            Describe what you need help with:


            ---
            App version: \(metadata.version)
            Build: \(metadata.build)
            iOS: \(metadata.iOSVersion)
            Device: \(metadata.deviceModel)
            """
        )
    }
}

@MainActor
protocol SupportMailPresenting {
    var canSendMail: Bool { get }
}

@MainActor
struct SystemSupportMailPresenter: SupportMailPresenting {
    var canSendMail: Bool { MFMailComposeViewController.canSendMail() }
}

@MainActor
protocol AppRatingPresenting {
    @discardableResult func requestReview() -> Bool
}

@MainActor
struct StoreKitAppRatingPresenter: AppRatingPresenting {
    @discardableResult
    func requestReview() -> Bool {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return false }
        SKStoreReviewController.requestReview(in: scene)
        return true
    }
}
