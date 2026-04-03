import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ZStack {
            Color.trBase.ignoresSafeArea()
        VStack(spacing: 40) {
            Spacer()

            // Logo & branding
            VStack(spacing: 12) {
                TrailRiderIcon(size: 180)

                HStack(spacing: 0) {
                    Text("TRAIL").foregroundStyle(.trTextPrimary)
                    Text("RIDER").foregroundStyle(.trPrimary)
                }
                .font(.system(size: 42, weight: .bold))

                Text("Track rides. Find friends. Own the trail.")
                    .font(.subheadline)
                    .foregroundStyle(.trTextSecondary)
            }

            Spacer()

            // Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                authViewModel.handleSignInRequest(request)
            } onCompletion: { result in
                authViewModel.handleSignInCompletion(result)
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 54)
            .padding(.horizontal, 40)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.trDestructive)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            #if DEBUG
            Button("Skip to App (Dev)") {
                authViewModel.devBypass()
            }
            .font(.caption)
            .foregroundStyle(.trTextSecondary)
            #endif

            Spacer()
                .frame(height: 40)
        }
        .padding()
        } // ZStack
    }
}
