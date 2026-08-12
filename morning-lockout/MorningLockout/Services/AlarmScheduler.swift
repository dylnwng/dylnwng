import Foundation
import AlarmKit

/// Wraps AlarmKit (iOS 26+) — the OS-owned alarm mechanism that rings through
/// silent mode/Focus, survives the app being killed, and presents full-screen
/// even when locked. See PRD.md §5/§6.1 for why this replaces the old
/// "fake an alarm with local notifications" approach.
///
/// Verified against the real iOS 26.5 SDK via CI (macos-26 runner, Xcode 26.6).
/// Two spots differed from the WWDC25-era sketch this was first written against:
/// `Recurrence` has no `.daily` case (only `.never`/`.weekly([Locale.Weekday])`), and
/// `AlarmConfiguration` has no plain `init(schedule:attributes:stopIntent:)` — use the
/// `.alarm(...)` factory, which also requires `secondaryIntent`/`sound`.
protocol AlarmScheduling {
    /// Requests the AlarmKit authorization prompt. Must succeed before scheduling.
    func requestAuthorization() async throws -> Bool

    /// Schedules the daily alarm for the given settings. Re-calling replaces any existing alarm.
    func schedule(settings: LockoutSettings) async throws

    /// Cancels the scheduled alarm entirely (e.g. user disables the feature).
    func cancel() async throws

    /// Stops the currently-ringing alarm. Only call this after the dismissal challenge is actually completed.
    func stopRinging(alarmID: UUID) async throws

    /// Emits an alarm's ID each time it transitions into AlarmKit's .alerting (currently firing)
    /// state. This is what actually connects an alarm ringing to the in-app dismissal-challenge
    /// flow — AppViewModel observes this stream and calls alarmDidFire(alarmID:) on each new ID;
    /// nothing else calls alarmDidFire.
    var alertingAlarmIDs: AsyncStream<UUID> { get }
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
                // Recurrence has no .daily case — only .never and .weekly([Locale.Weekday]),
                // and Locale.Weekday isn't CaseIterable, so "every day" means spelling out all 7.
                repeats: .weekly([.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
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

        // AlarmConfiguration has no plain init(schedule:attributes:stopIntent:) — the real
        // initializers/factories all also require secondaryIntent and sound. .alarm(...) is
        // the scheduled (non-countdown) factory, which fits this use case.
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            // Do not offer a native "stop" tap target — dismissal must go through the
            // in-app challenge screen (AlarmView), not AlarmKit's default stop button.
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .default
        )

        _ = try await AlarmManager.shared.schedule(id: Self.alarmID, configuration: configuration)
    }

    func cancel() async throws {
        // cancel(id:)/stop(id:) are synchronous throws, not async — no `await` needed.
        try AlarmManager.shared.cancel(id: Self.alarmID)
    }

    func stopRinging(alarmID: UUID) async throws {
        try AlarmManager.shared.stop(id: alarmID)
    }

    var alertingAlarmIDs: AsyncStream<UUID> {
        AsyncStream { continuation in
            let task = Task {
                for await alarms in AlarmManager.shared.alarmUpdates {
                    for alarm in alarms where alarm.state == .alerting {
                        continuation.yield(alarm.id)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Custom metadata surfaced on the AlarmKit Live Activity/lock-screen presentation.
struct MorningLockoutMetadata: AlarmMetadata {
    var dismissalStepTarget: Int
}
