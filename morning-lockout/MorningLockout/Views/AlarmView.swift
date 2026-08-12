import SwiftUI

/// Full-screen, non-dismissable-by-tap alarm UI shown once AlarmKit hands control to the app.
/// Real dismissal happens by completing the configured challenge — see PRD.md §6.1. No back
/// button, no swipe-to-dismiss on purpose.
struct AlarmView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var challengeComplete: Bool { viewModel.dismissalChallengeComplete }

    var body: some View {
        ZStack {
            Color.red.ignoresSafeArea()

            VStack(spacing: 20) {
                Text(alarmTimeText)
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)

                switch viewModel.settings.dismissalChallenge {
                case .steps:
                    stepsChallenge
                case .math:
                    mathChallenge
                }

                Button(challengeComplete ? "Dismiss alarm" : "Keep going...") {
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

    // MARK: - Steps challenge

    private var stepsTarget: Int { viewModel.settings.dismissalStepTarget }

    private var stepsChallenge: some View {
        VStack(spacing: 20) {
            Text("Walk \(stepsTarget) steps to stop the alarm.")
                .font(.title3)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("\(min(viewModel.stepsSinceAlarm, stepsTarget)) / \(stepsTarget) steps")
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
        }
    }

    // MARK: - Math challenge

    private var mathChallenge: some View {
        MathChallengeView(
            problemsSolved: viewModel.mathProblemsSolved,
            problemCount: viewModel.settings.dismissalMathProblemCount,
            currentProblem: viewModel.currentMathProblem,
            onSubmit: { viewModel.submitMathAnswer($0) }
        )
    }

    private var alarmTimeText: String {
        let s = viewModel.settings
        return String(format: "%02d:%02d", s.alarmTime.hour ?? 0, s.alarmTime.minute ?? 0)
    }
}

/// Isolated so its @State (the in-progress answer text, wrong-answer feedback) resets cleanly
/// each time a new problem appears, without AlarmView itself needing to own that state.
private struct MathChallengeView: View {
    let problemsSolved: Int
    let problemCount: Int
    let currentProblem: MathProblem?
    let onSubmit: (Int) -> Bool

    @State private var answerText = ""
    @State private var showWrongAnswer = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Problem \(min(problemsSolved + 1, problemCount)) of \(problemCount)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            if let problem = currentProblem {
                Text(problem.prompt)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)

                TextField("Answer", text: $answerText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .padding()
                    .frame(maxWidth: 160)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)

                if showWrongAnswer {
                    Text("Not quite — try again.")
                        .font(.caption)
                        .foregroundStyle(.white)
                }

                Button("Submit") {
                    guard let value = Int(answerText) else { return }
                    let correct = onSubmit(value)
                    showWrongAnswer = !correct
                    answerText = ""
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(Int(answerText) == nil)
            } else {
                Text("All problems solved.")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
    }
}
