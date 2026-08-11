import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Morning Lockout")
                    .font(.largeTitle.bold())

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if viewModel.isPausedToday {
                    Label("Paused for today", systemImage: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button("Settings") { showingSettings = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var summary: String {
        let s = viewModel.settings
        let time = String(format: "%02d:%02d", s.alarmTime.hour ?? 0, s.alarmTime.minute ?? 0)
        return "Alarm at \(time) · \(s.lockoutMinutes) min lockout · \(s.activityTarget) steps"
    }
}
