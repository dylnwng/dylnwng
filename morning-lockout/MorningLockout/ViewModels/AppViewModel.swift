import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var settings: LockoutSettings
    @Published var phase: AppPhase = .idle
    @Published var progress: GateProgress
    @Published var currentAlarmID: UUID?

    private let alarmScheduler: AlarmScheduling
    private let activityMonitor: ActivityMonitoring
    private let appShield: AppShielding
    private var lockoutTimer: Timer?

    private static let settingsKey = "morningLockout.settings"

    init(
        alarmScheduler: AlarmScheduling = AlarmScheduler(),
        activityMonitor: ActivityMonitoring = ActivityMonitor(),
        appShield: AppShielding = AppShield()
    ) {
        let loaded = Self.loadSettings() ?? .default
        self.settings = loaded
        self.progress = GateProgress(
            lockoutTargetSeconds: loaded.lockoutMinutes * 60,
            activityTarget: loaded.activityTarget
        )
        self.alarmScheduler = alarmScheduler
        self.activityMonitor = activityMonitor
        self.appShield = appShield
    }

    func updateSettings(_ newSettings: LockoutSettings) {
        settings = newSettings
        Self.saveSettings(newSettings)
        Task { try? await alarmScheduler.schedule(settings: newSettings) }
    }

    func requestPermissions() async throws {
        _ = try await alarmScheduler.requestAuthorization()
        try await appShield.requestAuthorization()
    }

    /// Called when AlarmKit's system alarm fires and hands control to the app (or the app is
    /// foregrounded from the alert). Begins the dismissal-challenge flow.
    func alarmDidFire(alarmID: UUID) {
        currentAlarmID = alarmID
        phase = .alarming
    }

    /// Called once the dismissal challenge (steps/math) is actually completed — not on a bare tap.
    func dismissAlarm() {
        guard let alarmID = currentAlarmID else { return }
        Task { try? await alarmScheduler.stopRinging(alarmID: alarmID) }
        beginGate()
    }

    private func beginGate() {
        phase = .gated
        progress = GateProgress(
            lockoutTargetSeconds: settings.lockoutMinutes * 60,
            activityTarget: settings.activityTarget
        )
        appShield.engage()
        activityMonitor.startTracking(type: settings.activityType, target: settings.activityTarget) { [weak self] value in
            self?.progress.activityProgress = value
            self?.checkGate()
        }

        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.progress.lockoutElapsedSeconds += 1
                self?.checkGate()
            }
        }
    }

    private func checkGate() {
        guard progress.isSatisfied, phase == .gated else { return }
        lockoutTimer?.invalidate()
        lockoutTimer = nil
        activityMonitor.stopTracking()
        appShield.release()
        phase = .unlocked
    }

    private static func loadSettings() -> LockoutSettings? {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else { return nil }
        return try? JSONDecoder().decode(LockoutSettings.self, from: data)
    }

    private static func saveSettings(_ settings: LockoutSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }
}
