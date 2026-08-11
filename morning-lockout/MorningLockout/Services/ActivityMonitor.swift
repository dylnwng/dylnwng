import Foundation
import CoreMotion

/// Verifies physical activity toward the gate's target. Steps via CMPedometer
/// are the primary method; sustained accelerometer motion is the fallback for
/// when step data is unavailable (no hardware support, or permission denied).
/// See PRD.md §6.2.
protocol ActivityMonitoring {
    func startTracking(type: ActivityVerificationType, target: Int, onProgress: @escaping (Int) -> Void)
    func stopTracking()
}

final class ActivityMonitor: ActivityMonitoring {
    private let pedometer = CMPedometer()
    private let motionActivityManager = CMMotionActivityManager()
    private var trackingStartDate: Date?
    private var motionTimer: Timer?

    func startTracking(type: ActivityVerificationType, target: Int, onProgress: @escaping (Int) -> Void) {
        trackingStartDate = Date()

        switch type {
        case .steps:
            startStepTracking(onProgress: onProgress, fallbackTarget: target)

        case .motion:
            startMotionTracking(onProgress: onProgress)
        }
    }

    func stopTracking() {
        pedometer.stopUpdates()
        motionActivityManager.stopActivityUpdates()
        motionTimer?.invalidate()
        motionTimer = nil
        trackingStartDate = nil
    }

    private func startStepTracking(onProgress: @escaping (Int) -> Void, fallbackTarget: Int) {
        guard CMPedometer.isStepCountingAvailable() else {
            startMotionTracking(onProgress: onProgress)
            return
        }

        // Permission denial/restriction can't be recovered from mid-session — CMPedometer never
        // calls back in that state, which would silently stall the gate forever. Fall back to
        // motion tracking instead so there's always some path to unlocking.
        switch CMPedometer.authorizationStatus() {
        case .denied, .restricted:
            startMotionTracking(onProgress: onProgress)
            return
        default:
            break // .notDetermined prompts the user automatically on the startUpdates call below; .authorized proceeds normally.
        }

        pedometer.startUpdates(from: trackingStartDate ?? Date()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            DispatchQueue.main.async {
                onProgress(data.numberOfSteps.intValue)
            }
        }
    }

    /// Approximates "activity" as seconds of detected walking/running motion — coarser than a
    /// step count, used only when real step data isn't available. Ticks a 1-second timer that
    /// only advances while CMMotionActivityManager currently reports walking or running.
    private func startMotionTracking(onProgress: @escaping (Int) -> Void) {
        var isMoving = false
        var movingSeconds = 0

        motionActivityManager.startActivityUpdates(to: .main) { activity in
            guard let activity else { return }
            isMoving = activity.walking || activity.running
        }

        motionTimer?.invalidate()
        motionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard isMoving else { return }
            movingSeconds += 1
            onProgress(movingSeconds)
        }
    }
}
