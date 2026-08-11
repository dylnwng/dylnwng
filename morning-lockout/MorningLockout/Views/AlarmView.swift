import SwiftUI

/// Full-screen, non-dismissable-by-tap alarm UI shown once AlarmKit hands control to the app.
/// Real dismissal happens by completing the configured challenge — see PRD.md §6.1. No back
/// button, no swipe-to-dismiss on purpose.
struct AlarmView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var target: Int { viewModel.settings.dismissalStepTarget }
    private var stepsWalked: Int { viewModel.stepsSinceAlarm }
    private var challengeComplete: Bool { viewModel.dismissalChallengeComplete }

    var body: some View {
        ZStack {
            Color.red.ignoresSafeArea()

            VStack(spacing: 20) {
                Text(alarmTimeText)
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)

                Text("Walk \(target) steps to stop the alarm.")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("\(min(stepsWalked, target)) / \(target) steps")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                #if targetEnvironment(simulator)
                // Simulator has no real pedometer hardware, so CMPedometer never reports steps
                // there — this button exists only so the flow is testable without a device.
                // Compiled out of every real-device build, debug or release: a step-count cheat
                // button has no business existing on the phone this app is supposed to gate.
                Button("+10 steps (simulator only)") { viewModel.stepsSinceAlarm += 10 }
                    .buttonStyle(.bordered)
                    .tint(.white)
                #endif

                Button(challengeComplete ? "Dismiss alarm" : "Keep moving...") {
                    viewModel.dismissAlarm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .disabled(!challengeComplete)
                .foregroundStyle(.red)
            }
            .padding()

            VStack {
                Spacer()
                Text("Emergency call is always available from the lock screen.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 24)
            }
        }
    }

    private var alarmTimeText: String {
        let s = viewModel.settings
        return String(format: "%02d:%02d", s.alarmTime.hour ?? 0, s.alarmTime.minute ?? 0)
    }
}
