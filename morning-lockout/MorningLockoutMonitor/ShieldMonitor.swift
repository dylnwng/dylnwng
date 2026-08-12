import DeviceActivity
import ManagedSettings
import Foundation

/// DeviceActivityMonitor extension — runs in its own process, independent of the main
/// app, so the lockout shield stays enforced even if the main app isn't running (e.g.
/// right after a reboot). Registered in project.yml as the MorningLockoutMonitor target's
/// NSExtensionPrincipalClass. See PRD.md §6.3 and AppShield.startMonitoring(_:).
class ShieldMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // The main app already engages the shield synchronously when the alarm is dismissed
        // (AppShield.engage()); this is the reboot/background-relaunch safety net. Must exclude
        // this app's own token the same way AppShield.engage() does — otherwise this path shields
        // Morning Lockout too, locking the user out of the unlock UI it's supposed to show.
        store.shield.applicationCategories = .all(except: AppGroupStore.ownApplicationTokens())
        store.shield.webDomainCategories = .all()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }
}
