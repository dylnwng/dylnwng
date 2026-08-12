import SwiftUI
import FamilyControls

/// One-time setup: explains why each OS permission is requested (PRD.md §6.4), then
/// requests AlarmKit + Family Controls authorization, and captures this app's own
/// FamilyActivitySelection so AppShield can exclude it from the "shield everything" policy.
struct OnboardingView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var didOnboard: Bool

    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var permissionError: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Morning Lockout needs a few permissions")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    "Alarms",
                    "So the wake-up alarm rings at full volume even in silent mode, and survives the app being closed."
                )
                permissionRow(
                    "Screen Time (Family Controls)",
                    "So other apps can be shielded during the lockout window."
                )
                permissionRow(
                    "Motion & Fitness",
                    "So step count can verify you've actually moved before unlocking."
                )
            }
            .padding()

            Button("Select this app (so it isn't shielded)") { showingPicker = true }
                .buttonStyle(.bordered)
                .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
                .onChange(of: selection) { _, newSelection in
                    AppGroupStore.saveOwnAppSelection(newSelection)
                }

            if let permissionError {
                Text(permissionError).font(.caption).foregroundStyle(.red)
            }

            Button("Grant permissions & continue") {
                Task { await requestPermissions() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func permissionRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func requestPermissions() async {
        do {
            try await viewModel.requestPermissions()
            didOnboard = true
        } catch {
            permissionError = "Permission request failed: \(error.localizedDescription)"
        }
    }
}
