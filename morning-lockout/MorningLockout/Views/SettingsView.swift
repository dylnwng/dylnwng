import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LockoutSettings = .default
    @State private var showingPauseConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm dismissal") {
                    DatePicker(
                        "Time",
                        selection: alarmTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    Picker("Challenge", selection: $draft.dismissalChallenge) {
                        Text("Walk steps").tag(DismissalChallengeType.steps)
                        Text("Solve math problems").tag(DismissalChallengeType.math)
                    }
                    if draft.dismissalChallenge == .steps {
                        Stepper(
                            "Steps to dismiss: \(draft.dismissalStepTarget)",
                            value: $draft.dismissalStepTarget,
                            in: 10...500,
                            step: 10
                        )
                    } else {
                        Stepper(
                            "Problems to solve: \(draft.dismissalMathProblemCount)",
                            value: $draft.dismissalMathProblemCount,
                            in: LockoutSettings.dismissalMathProblemCountRange
                        )
                    }
                }

                Section("Lockout") {
                    Stepper(
                        "Duration: \(draft.lockoutMinutes) min",
                        value: $draft.lockoutMinutes,
                        in: LockoutSettings.lockoutMinutesRange,
                        step: 5
                    )
                    Stepper(
                        "Activity target: \(draft.activityTarget) steps",
                        value: $draft.activityTarget,
                        in: 50...2000,
                        step: 50
                    )
                }

                Section {
                    if viewModel.isPausedToday {
                        Label("Lockout paused for the rest of today", systemImage: "pause.circle.fill")
                            .foregroundStyle(.orange)
                        Button("Resume enforcement now") {
                            viewModel.resumeEnforcementToday()
                        }
                    } else {
                        Button("Pause for today", role: .destructive) {
                            showingPauseConfirmation = true
                        }
                    }
                } footer: {
                    Text("The alarm still rings and still requires the dismissal challenge — pausing only skips the lockout/activity gate afterward, for today only. Resets automatically tomorrow.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateSettings(draft)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { draft = viewModel.settings }
            .confirmationDialog(
                "Pause lockout for today?",
                isPresented: $showingPauseConfirmation,
                titleVisibility: .visible
            ) {
                Button("Pause today only", role: .destructive) {
                    viewModel.pauseForToday()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This defeats the point of the app for today. Only use it for real exceptions — travel, illness, injury.")
            }
        }
    }

    private var alarmTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: draft.alarmTime) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                draft.alarmTime = comps
            }
        )
    }
}
