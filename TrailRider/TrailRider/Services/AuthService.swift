import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

final class AuthService: Sendable {
    static let shared = AuthService()

    private init() {}

    // MARK: - Sign in with Apple

    /// Generate a random nonce for Apple Sign-In security
    func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            throw NSError(domain: "AuthService", code: Int(errorCode), userInfo: [
                NSLocalizedDescriptionKey: "Unable to generate secure nonce"
            ])
        }
        // 64-char charset for uniform distribution (256 / 64 = 4, no modulo bias)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    /// SHA256 hash of the nonce
    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Authenticate with Firebase using Apple credential
    func signInWithApple(idToken: String, nonce: String) async throws -> FirebaseAuth.User {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    /// Sign out
    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Current Firebase user
    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    /// Current user ID
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
}
