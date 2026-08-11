import SwiftUI

/// The 30-minute-lockout + activity-gate screen (PRD.md §6.2/§6.3). Shown while
/// AppShield is engaged over every other app. Both the timer and the activity
/// target must be satisfied — enforced in AppViewModel.checkGate() — before
/// RootView routes back to HomeView.
struct GateView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Not yet.")
                .font(.largeTitle.bold())

            Text("\(viewModel.progress.minutesRemaining) min left in lockout")
                .font(.title3)

            Text("\(viewModel.progress.activityRemaining) more steps needed")
                .font(.title3)

            Spacer()

            Text("Other apps are shielded until both are done. Emergency dialing is never blocked.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
