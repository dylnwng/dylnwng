import Foundation
import FamilyControls
import ManagedSettings

/// Persists this app's own FamilyActivitySelection (captured once during onboarding, see
/// OnboardingView) in the shared App Group container, so both the main app (AppShield.engage())
/// and the MorningLockoutMonitor extension (ShieldMonitor, a separate process — see PRD.md §6.3)
/// read the same "don't shield yourself" token set instead of each needing its own copy.
enum AppGroupStore {
    static let suiteName = "group.com.dylnwng.morninglockout"
    private static let selectionKey = "morningLockout.ownAppSelection"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func saveOwnAppSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(data, forKey: selectionKey)
    }

    static func ownApplicationTokens() -> Set<ApplicationToken> {
        guard let data = defaults?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return [] }
        return selection.applicationTokens
    }
}
