import Foundation
import CoreMotion

/// Verifies physical activity toward the gate's target. Steps via CMPedometer
/// are the primary method; sustained accelerometer motion is the fallback for
/// when step data is delayed or the device doesn't support it. See PRD.md §6.2.
protocol ActivityMonitoring {
    func startTracking(type: ActivityVerificationType, target: Int, onProgress: @escaping (Int) -> Void)
    func stopTracking()
}

final class ActivityMonitor: ActivityMonitoring {
    private let pedometer = CMPedometer()
    private let motionActivityManager = CMMotionActivityManager()
    private var trackingStartDate: Date?

    func startTracking(type: ActivityVerificationType, target: Int, onProgress: @escaping (Int) -> Void) {
        trackingStartDate = Date()

        switch type {
        case .steps:
            guard CMPedometer.isStepCountingAvailable() else {
                // Fall back to motion-based tracking if step counting isn't available on this device.
                startTracking(type: .motion, target: target, onProgress: onProgress)
                return
            }
            pedometer.startUpdates(from: trackingStartDate!) { data, error in
                guard let data, error == nil else { return }
                DispatchQueue.main.async {
                    onProgress(data.numberOfSteps.intValue)
                }
            }

        case .motion:
            // Approximates "activity" as seconds of detected walking/running motion.
            // Coarser signal than step count — used only as a fallback.
            var motionSeconds = 0
            motionActivityManager.startActivityUpdates(to: .main) { activity in
                guard let activity, activity.walking || activity.running else { return }
                motionSeconds += 1
                onProgress(motionSeconds)
            }
        }
    }

    func stopTracking() {
        pedometer.stopUpdates()
        motionActivityManager.stopActivityUpdates()
        trackingStartDate = nil
    }
}
