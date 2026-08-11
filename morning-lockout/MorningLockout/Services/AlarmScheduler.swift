import Foundation
import AlarmKit

/// Wraps AlarmKit (iOS 26+) — the OS-owned alarm mechanism that rings through
/// silent mode/Focus, survives the app being killed, and presents full-screen
/// even when locked. See PRD.md §5/§6.1 for why this replaces the old
/// "fake an alarm with local notifications" approach.
///
/// NOTE: AlarmKit is a new framework. The exact type/method names below
/// (`AlarmManager`, `AlarmConfiguration`, `AlarmAttributes`, etc.) are written
/// to the framework's known shape from its WWDC25 introduction, but this file
/// has not been compiled against the real SDK — treat it as a best-effort
/// sketch and fix up against Xcode's autocomplete/current AlarmKit docs
/// before relying on it.
protocol AlarmScheduling {
    /// Requests the AlarmKit authorization prompt. Must succeed before scheduling.
    func requestAuthorization() async throws -> Bool

    /// Schedules the daily alarm for the given settings. Re-calling replaces any existing alarm.
    func schedule(settings: LockoutSettings) async throws

    /// Cancels the scheduled alarm entirely (e.g. user disables the feature).
    func cancel() async throws

    /// Stops the currently-ringing alarm. Only call this after the dismissal challenge is actually completed.
    func stopRinging(alarmID: UUID) async throws
}

final class AlarmScheduler: AlarmScheduling {
    static let alarmID = UUID() // stable ID for the single daily alarm this app manages

    func requestAuthorization() async throws -> Bool {
        let state = try await AlarmManager.shared.requestAuthorization()
        return state == .authorized
    }

    func schedule(settings: LockoutSettings) async throws {
        let schedule = Alarm.Schedule.relative(
            .init(
                time: .init(
                    hour: settings.alarmTime.hour ?? 6,
                    minute: settings.alarmTime.minute ?? 30
                ),
                repeats: .daily
            )
        )

        let presentation = AlarmPresentation.Alert(
            title: "Morning Lockout",
            stopButton: .init(text: "Dismiss", textColor: .white, systemImageName: "figure.walk")
        )

        let attributes = AlarmAttributes<MorningLockoutMetadata>(
            presentation: .init(alert: presentation),
            metadata: MorningLockoutMetadata(dismissalStepTarget: settings.dismissalStepTarget),
            tintColor: .red
        )

        let configuration = AlarmManager.AlarmConfiguration(
            schedule: schedule,
            attributes: attributes,
            // Do not offer a native "stop" tap target — dismissal must go through the
            // in-app challenge screen (AlarmView), not AlarmKit's default stop button.
            stopIntent: nil
        )

        _ = try await AlarmManager.shared.schedule(id: Self.alarmID, configuration: configuration)
    }

    func cancel() async throws {
        try await AlarmManager.shared.cancel(id: Self.alarmID)
    }

    func stopRinging(alarmID: UUID) async throws {
        try await AlarmManager.shared.stop(id: alarmID)
    }
}

/// Custom metadata surfaced on the AlarmKit Live Activity/lock-screen presentation.
struct MorningLockoutMetadata: AlarmMetadata {
    var dismissalStepTarget: Int
}
