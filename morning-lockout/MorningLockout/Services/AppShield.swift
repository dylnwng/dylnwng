import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Wraps Family Controls / ManagedSettings / DeviceActivity — Apple's Screen
/// Time framework, used here to shield all other apps during the lockout
/// window. See PRD.md §5 for why the *development* entitlement (added in
/// Xcode, no Apple approval needed) is sufficient for a personal, sideloaded
/// build, unlike the App Store *distribution* entitlement.
protocol AppShielding {
    /// Requests Family Controls authorization. Must succeed before engage()/release() do anything.
    func requestAuthorization() async throws

    /// Engages the shield over every app except this one. Never shields the phone/emergency dialer,
    /// which iOS keeps reachable from the lock screen regardless of app state.
    func engage()

    /// Releases the shield once the gate is satisfied.
    func release()
}

final class AppShield: AppShielding {
    private let store = ManagedSettingsStore()
    private let activityCenter = DeviceActivityCenter()
    private static let activityName = DeviceActivityName("morningLockoutGate")

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    func engage() {
        // Shields every category except this app itself. `except:` needs this app's own
        // ApplicationToken, obtained once via a FamilyActivityPicker selection during
        // onboarding and persisted — see OnboardingView. Verify `.all(except:)` against
        // current ManagedSettings docs; this is the piece most likely to need adjustment.
        store.shield.applicationCategories = .all(except: ownAppTokenSet())
        store.shield.webDomainCategories = .all()
    }

    func release() {
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }

    /// Starts a DeviceActivity monitoring window so the MorningLockoutMonitor extension
    /// can independently enforce the shield even if the main app isn't running — e.g.
    /// after the phone reboots mid-lockout.
    func startMonitoring(lockoutMinutes: Int) throws {
        let now = Date()
        let end = Calendar.current.date(byAdding: .minute, value: lockoutMinutes, to: now) ?? now
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: Calendar.current.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        try activityCenter.startMonitoring(Self.activityName, during: schedule)
    }

    func stopMonitoring() {
        activityCenter.stopMonitoring([Self.activityName])
    }

    private func ownAppTokenSet() -> Set<ApplicationToken> {
        AppGroupStore.ownApplicationTokens()
    }
}
