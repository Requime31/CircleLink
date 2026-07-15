import AuthenticationServices
import CryptoKit
import UIKit

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingIdentityToken
    case cancelled
    case simulatorOrConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Sign in with Apple credentials."
        case .missingIdentityToken:
            return "Sign in with Apple did not return an identity token."
        case .cancelled:
            return "Sign in with Apple was cancelled."
        case .simulatorOrConfiguration:
            return """
            Sign in with Apple failed. Check:
            1. Simulator: Settings → Apple Account → sign in
            2. Xcode → Signing & Capabilities → Sign In with Apple
            3. Firebase Console → Authentication → Apple → Enabled
            Or test on a real device.
            """
        }
    }
}

struct AppleSignInResult {
    let idToken: String
    let nonce: String
    let fullName: PersonNameComponents?
}

@MainActor
final class AppleSignInPresenter: NSObject {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce = ""

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.currentNonce = Self.randomNonce()

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(currentNonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        for _ in 0..<length {
            if let random = charset.randomElement() {
                result.append(random)
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInPresenter: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                continuation?.resume(throwing: AppleSignInError.invalidCredential)
                continuation = nil
                return
            }

            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
                continuation = nil
                return
            }

            continuation?.resume(
                returning: AppleSignInResult(
                    idToken: idToken,
                    nonce: currentNonce,
                    fullName: credential.fullName
                )
            )
            continuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                continuation?.resume(throwing: AppleSignInError.cancelled)
            } else if (error as NSError).code == ASAuthorizationError.unknown.rawValue {
                continuation?.resume(throwing: AppleSignInError.simulatorOrConfiguration)
            } else {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }
}

extension AppleSignInPresenter: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        return windowScene?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
