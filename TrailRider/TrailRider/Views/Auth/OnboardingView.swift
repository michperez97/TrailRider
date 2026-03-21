import SwiftUI

struct OnboardingView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var username = ""
    @State private var displayName = ""
    @State private var isSubmitting = false

    var isFormValid: Bool {
        username.count >= 3 && !displayName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.trBase.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Set Up Your Profile")
                        .font(.title.bold())
                        .foregroundStyle(.trTextPrimary)

                    Text("Choose a username and display name")
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)
                }

                VStack(spacing: 16) {
                    ThemedTextField(placeholder: "Display Name", text: $displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()

                    ThemedTextField(placeholder: "Username (min 3 characters)", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 24)

                Button {
                    isSubmitting = true
                    Task {
                        await authViewModel.completeOnboarding(
                            username: username,
                            displayName: displayName
                        )
                        isSubmitting = false
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Let's Ride")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .buttonStyle(.trailPrimary)
                .disabled(!isFormValid || isSubmitting)
                .padding(.horizontal, 24)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.trDestructive)
                }

                Spacer()
                Spacer()
            } // VStack
            } // ZStack
        }
    }
}
