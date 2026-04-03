import Foundation
import FirebaseFirestore

final class UserService: Sendable {
    static let shared = UserService()

    private var db: Firestore { Firestore.firestore() }
    private var usersCollection: CollectionReference { db.collection("users") }

    private init() {}

    // MARK: - CRUD

    /// Fetch user by ID
    func getUser(id: String) async throws -> AppUser? {
        let snapshot = try await usersCollection.document(id).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: AppUser.self)
    }

    /// Create a new user document
    func createUser(_ user: AppUser) async throws {
        guard let id = user.id else { return }
        try await usersCollection.document(id).setData(from: user)
    }

    /// Update user fields
    func updateUser(id: String, fields: [String: Any]) async throws {
        try await usersCollection.document(id).updateData(fields)
    }

    /// Check if username is available
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let snapshot = try await usersCollection
            .whereField("username", isEqualTo: username.lowercased())
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.isEmpty
    }

    func claimUsername(_ username: String, userId: String) async throws {
        let usernameRef = db.collection("usernames").document(username.lowercased())
        let userRef = usersCollection.document(userId)

        _ = try await db.runTransaction { transaction, errorPointer in
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(usernameRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            if doc.exists {
                let error = NSError(
                    domain: "UserService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "Username is already taken"]
                )
                errorPointer?.pointee = error
                return nil
            }

            transaction.setData(["userId": userId], forDocument: usernameRef)
            transaction.updateData(["username": username.lowercased()], forDocument: userRef)
            return nil
        }
    }

    /// Check if user document exists
    func userExists(id: String) async throws -> Bool {
        let snapshot = try await usersCollection.document(id).getDocument()
        return snapshot.exists
    }
}
