import Foundation
import AuthenticationServices
import FirebaseAuth

@Observable
@MainActor
final class AuthViewModel {

    enum AuthState: Equatable {
        case loading
        case signedOut
        case onboarding
        case signedIn
    }

    var authState: AuthState = .loading
    var currentUser: AppUser?
    var errorMessage: String?

    private var currentNonce: String?
    private let authService = AuthService.shared
    private let userService = UserService.shared
    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        // Defer auth listener to avoid calling Auth.auth() before FirebaseApp.configure()
        Task { @MainActor in
            self.listenToAuthChanges()
        }
    }

    // MARK: - Auth State Listener

    private func listenToAuthChanges() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                if let user {
                    await self.handleSignedIn(firebaseUser: user)
                } else {
                    self.authState = .signedOut
                    self.currentUser = nil
                }
            }
        }
    }

    private func handleSignedIn(firebaseUser: FirebaseAuth.User) async {
        do {
            if let appUser = try await userService.getUser(id: firebaseUser.uid) {
                if appUser.username.isEmpty {
                    authState = .onboarding
                } else {
                    currentUser = appUser
                    authState = .signedIn
                }
            } else {
                // First time user — create document, go to onboarding
                let newUser = AppUser.new(id: firebaseUser.uid)
                try await userService.createUser(newUser)
                currentUser = newUser
                authState = .onboarding
            }
        } catch {
            errorMessage = error.localizedDescription
            authState = .signedOut
        }
    }

    // MARK: - Refresh

    func refreshCurrentUser() async {
        guard let uid = authService.currentUserId else { return }
        do {
            currentUser = try await userService.getUser(id: uid)
        } catch {
            // Stale data is preferable to a crash — silently keep existing values
        }
    }

    // MARK: - Sign in with Apple

    func handleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try authService.randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = authService.sha256(nonce)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    nonisolated deinit {
        let listener = MainActor.assumeIsolated { authListener }
        if let listener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    func handleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = appleIDCredential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Failed to get Apple ID credentials"
                return
            }

            Task {
                do {
                    _ = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                    // Auth listener will handle the state change
                } catch {
                    errorMessage = error.localizedDescription
                }
            }

        case .failure(let error):
            // User cancelled is not an error we need to show
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Onboarding

    func completeOnboarding(username: String, displayName: String) async {
        guard let userId = authService.currentUserId else { return }
        do {
            let trimmed = username.trimmingCharacters(in: .whitespaces)
            let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
            guard trimmed.unicodeScalars.allSatisfy({ validChars.contains($0) }) else {
                errorMessage = "Username can only contain letters, numbers, and underscores"
                return
            }

            let trimmedDisplay = displayName.trimmingCharacters(in: .whitespaces)
            guard !trimmedDisplay.isEmpty else {
                errorMessage = "Display name cannot be empty"
                return
            }

            try await userService.claimUsername(trimmed.lowercased(), userId: userId)
            try await userService.updateUser(id: userId, fields: ["displayName": trimmedDisplay])

            if currentUser == nil {
                currentUser = try await userService.getUser(id: userId)
            }
            currentUser?.username = trimmed.lowercased()
            currentUser?.displayName = trimmedDisplay
            authState = .signedIn
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Dev Bypass (remove before production)

    #if DEBUG
    func devBypass() {
        currentUser = AppUser(
            id: "dev-user",
            username: "devrider",
            displayName: "Dev Rider",
            totalMiles: 42.5,
            currentStreak: 3,
            isRiding: false,
            shareLocation: true,
            createdAt: Date()
        )
        authState = .signedIn
    }
    #endif

    // MARK: - Sign Out

    func signOut() {
        #if DEBUG
        if currentUser?.id == "dev-user" {
            authState = .signedOut
            currentUser = nil
            return
        }
        #endif
        do {
            try authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
