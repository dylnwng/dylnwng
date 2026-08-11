import SwiftUI

struct RootView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @AppStorage("morningLockout.didOnboard") private var didOnboard = false

    var body: some View {
        Group {
            if !didOnboard {
                OnboardingView(didOnboard: $didOnboard)
            } else {
                switch viewModel.phase {
                case .idle, .unlocked:
                    HomeView()
                case .alarming:
                    AlarmView()
                case .gated:
                    GateView()
                }
            }
        }
    }
}
