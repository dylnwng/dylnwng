import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var settings: LockoutSettings
    @Published var phase: AppPhase = .idle
    @Published var progress: GateProgress
    @Published var currentAlarmID: UUID?
    /// Live step count since the alarm fired. Drives the alarm's dismissal challenge, and — since
    /// tracking runs continuously across the alarm→gate transition — carries straight into
    /// progress.activityProgress once the gate starts, so steps taken to silence the alarm count
    /// toward the gate target instead of being thrown away.
    @Published var stepsSinceAlarm = 0
    /// Math dismissal challenge state (used when settings.dismissalChallenge == .math).
    @Published var currentMathProblem: MathProblem?
    @Published var mathProblemsSolved = 0
    /// Set (with a timestamp) when the user pauses enforcement for today via the two-step
    /// confirmation in Settings. Self-expiring: isPausedToday only reads true on the calendar
    /// day it was set, so there's no separate "resume" step required the next morning.
    @Published private(set) var pausedDate: Date? {
        didSet { Self.savePausedDate(pausedDate) }
    }

    private let alarmScheduler: AlarmScheduling
    private let activityMonitor: ActivityMonitoring
    private let appShield: AppShielding
    private var lockoutTimer: Timer?

    private static let settingsKey = "morningLockout.settings"
    private static let pausedDateKey = "morningLockout.pausedDate"

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
        self.pausedDate = Self.loadPausedDate()
        self.alarmScheduler = alarmScheduler
        self.activityMonitor = activityMonitor
        self.appShield = appShield
    }

    var isPausedToday: Bool {
        guard let pausedDate else { return false }
        return Calendar.current.isDateInToday(pausedDate)
    }

    /// Pauses lockout+gate enforcement for the rest of today only. The alarm still rings and
    /// still requires the dismissal challenge — this skips the *lockout*, not the wake-up.
    /// Intentionally only reachable via a two-step confirmation in Settings, not a one-tap toggle.
    func pauseForToday() {
        pausedDate = Date()
    }

    func resumeEnforcementToday() {
        pausedDate = nil
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
    /// foregrounded from the alert). Begins the dismissal-challenge flow. When the challenge is
    /// step-based, activity tracking starts right here (not at gate-start) so the walking that
    /// silences the alarm is the same walking that counts toward the gate — one continuous
    /// pedometer session, not two that reset each other.
    func alarmDidFire(alarmID: UUID) {
        currentAlarmID = alarmID
        phase = .alarming
        stepsSinceAlarm = 0
        mathProblemsSolved = 0
        currentMathProblem = nil

        switch settings.dismissalChallenge {
        case .steps:
            let gateTarget = max(settings.dismissalStepTarget, settings.activityTarget)
            activityMonitor.startTracking(type: .steps, target: gateTarget) { [weak self] value in
                guard let self else { return }
                self.stepsSinceAlarm = value
                if self.phase == .gated {
                    self.progress.activityProgress = value
                    self.checkGate()
                }
            }
        case .math:
            currentMathProblem = MathProblem.generate(index: 1)
        }
    }

    /// Checks a submitted answer against the current math problem. Returns whether it was
    /// correct so AlarmView can show feedback. Advances to the next (harder) problem on a
    /// correct answer; a wrong answer doesn't lose progress, it just doesn't advance.
    @discardableResult
    func submitMathAnswer(_ value: Int) -> Bool {
        guard let problem = currentMathProblem, value == problem.answer else { return false }
        mathProblemsSolved += 1
        currentMathProblem = mathProblemsSolved < settings.dismissalMathProblemCount
            ? MathProblem.generate(index: mathProblemsSolved + 1)
            : nil
        return true
    }

    /// Whether the configured dismissal challenge has actually been completed. AlarmView disables
    /// its dismiss button on this too, but dismissAlarm() re-checks it rather than trusting the
    /// view — the whole point of this app is that dismissal can't be faked from the UI layer.
    var dismissalChallengeComplete: Bool {
        switch settings.dismissalChallenge {
        case .steps:
            return stepsSinceAlarm >= settings.dismissalStepTarget
        case .math:
            return mathProblemsSolved >= settings.dismissalMathProblemCount
        }
    }

    /// Called when the user taps dismiss. No-ops unless the challenge is genuinely complete.
    /// If today is paused (see pauseForToday()), the alarm and its challenge still had to be
    /// completed, but dismissing skips straight past the lockout/activity gate.
    func dismissAlarm() {
        guard dismissalChallengeComplete, let alarmID = currentAlarmID else { return }
        Task { try? await alarmScheduler.stopRinging(alarmID: alarmID) }
        guard !isPausedToday else {
            phase = .unlocked
            return
        }
        beginGate()
    }

    private func beginGate() {
        phase = .gated
        progress = GateProgress(
            lockoutTargetSeconds: settings.lockoutMinutes * 60,
            activityProgress: settings.dismissalChallenge == .steps ? stepsSinceAlarm : 0,
            activityTarget: settings.activityTarget
        )

        appShield.engage()

        // If the dismissal challenge wasn't step-based (e.g. math), tracking hasn't started yet —
        // start it fresh now. Otherwise it's already running continuously from alarmDidFire().
        if settings.dismissalChallenge != .steps {
            activityMonitor.startTracking(type: settings.activityType, target: settings.activityTarget) { [weak self] value in
                self?.progress.activityProgress = value
                self?.checkGate()
            }
        }

        lockoutTimer?.invalidate()
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.progress.lockoutElapsedSeconds += 1
                self?.checkGate()
            }
        }

        checkGate() // covers the case where the dismissal steps already satisfy the gate target
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

    private static func loadPausedDate() -> Date? {
        UserDefaults.standard.object(forKey: pausedDateKey) as? Date
    }

    private static func savePausedDate(_ date: Date?) {
        guard let date else {
            UserDefaults.standard.removeObject(forKey: pausedDateKey)
            return
        }
        UserDefaults.standard.set(date, forKey: pausedDateKey)
    }
}
