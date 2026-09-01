import Combine
import Foundation
import SwiftUI

enum AppAppearance: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// App-wide source of truth for the user's preferred appearance.
@MainActor
final class AppAppearanceStore: ObservableObject {
    static let storageKey = "appAppearance"

    @Published var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Self.storageKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedValue = defaults.string(forKey: Self.storageKey)
        appearance = storedValue.flatMap(AppAppearance.init(rawValue:)) ?? .system
    }
}
