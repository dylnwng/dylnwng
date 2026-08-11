import Foundation

enum ActivityVerificationType: String, Codable, CaseIterable {
    case steps
    case motion
}

enum DismissalChallengeType: String, Codable, CaseIterable {
    case steps
    case math
}

struct LockoutSettings: Codable, Equatable {
    var alarmTime: DateComponents // hour/minute only, local time
    var lockoutMinutes: Int
    var activityTarget: Int
    var activityType: ActivityVerificationType
    var dismissalChallenge: DismissalChallengeType
    var dismissalStepTarget: Int
    var dismissalGraceMinutes: Int

    static let `default` = LockoutSettings(
        alarmTime: DateComponents(hour: 6, minute: 30),
        lockoutMinutes: 30,
        activityTarget: 300,
        activityType: .steps,
        dismissalChallenge: .steps,
        dismissalStepTarget: 50,
        dismissalGraceMinutes: 2
    )

    static let lockoutMinutesRange = 5...90
}
