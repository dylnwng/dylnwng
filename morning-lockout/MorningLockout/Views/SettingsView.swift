import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LockoutSettings = .default

    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm") {
                    DatePicker(
                        "Time",
                        selection: alarmTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    Stepper(
                        "Dismissal steps: \(draft.dismissalStepTarget)",
                        value: $draft.dismissalStepTarget,
                        in: 10...500,
                        step: 10
                    )
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
