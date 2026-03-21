import SwiftUI

struct RootView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .loading:
                ZStack {
                    Color.trBase.ignoresSafeArea()
                    ProgressView().tint(.trPrimary)
                }
            case .signedOut:
                SignInView()
            case .onboarding:
                OnboardingView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.easeInOut, value: authViewModel.authState)
        .preferredColorScheme(.dark)
    }
}
