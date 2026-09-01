import SwiftUI
import Testing
@testable import CircleLink

@MainActor
struct AppAppearanceStoreTests {
    @Test
    func defaultsToSystemWhenNoValueIsStored() {
        withDefaults { defaults in
            let store = AppAppearanceStore(defaults: defaults)

            #expect(store.appearance == .system)
        }
    }

    @Test
    func restoresPersistedAppearance() {
        withDefaults { defaults in
            defaults.set(AppAppearance.dark.rawValue, forKey: AppAppearanceStore.storageKey)

            let store = AppAppearanceStore(defaults: defaults)

            #expect(store.appearance == .dark)
        }
    }

    @Test
    func persistsAppearanceChanges() {
        withDefaults { defaults in
            let store = AppAppearanceStore(defaults: defaults)

            store.appearance = .light

            #expect(defaults.string(forKey: AppAppearanceStore.storageKey) == AppAppearance.light.rawValue)
        }
    }

    @Test
    func unknownStoredValueFallsBackToSystem() {
        withDefaults { defaults in
            defaults.set("sepia", forKey: AppAppearanceStore.storageKey)

            let store = AppAppearanceStore(defaults: defaults)

            #expect(store.appearance == .system)
        }
    }

    @Test(arguments: [
        (AppAppearance.system, nil),
        (AppAppearance.light, ColorScheme.light),
        (AppAppearance.dark, ColorScheme.dark)
    ])
    func mapsAppearanceToColorScheme(appearance: AppAppearance, expected: ColorScheme?) {
        #expect(appearance.colorScheme == expected)
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "AppAppearanceStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        body(defaults)
    }
}
