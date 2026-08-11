import Foundation

enum AppPhase {
    case idle       // before alarm time, normal phone use
    case alarming   // alarm is sounding, dismissal challenge in progress
    case gated      // alarm dismissed, lockout timer + activity gate running
    case unlocked   // both thresholds met, normal phone use restored
}

struct GateProgress: Equatable {
    var lockoutElapsedSeconds: Int = 0
    var lockoutTargetSeconds: Int
    var activityProgress: Int = 0
    var activityTarget: Int

    var isSatisfied: Bool {
        lockoutElapsedSeconds >= lockoutTargetSeconds && activityProgress >= activityTarget
    }

    var minutesRemaining: Int {
        max(0, Int(ceil(Double(lockoutTargetSeconds - lockoutElapsedSeconds) / 60.0)))
    }

    var activityRemaining: Int {
        max(0, activityTarget - activityProgress)
    }
}
