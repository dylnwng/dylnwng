import SwiftUI

/// Full-screen, non-dismissable-by-tap alarm UI shown once AlarmKit hands control to the app.
/// Real dismissal happens by completing the configured challenge — see PRD.md §6.1. No back
/// button, no swipe-to-dismiss on purpose.
struct AlarmView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var stepsWalked = 0

    private var target: Int { viewModel.settings.dismissalStepTarget }
    private var challengeComplete: Bool { stepsWalked >= target }

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

                Text("\(stepsWalked) / \(target) steps")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                // Dev-only simulator button — replace with real ActivityMonitor progress callback
                // once this is wired up to run against a physical device.
                Button("+10 steps (dev-only simulator)") { stepsWalked += 10 }
                    .buttonStyle(.bordered)
                    .tint(.white)

                Button(challengeComplete ? "Dismiss alarm" : "Keep moving...") {
                    guard challengeComplete else { return }
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
