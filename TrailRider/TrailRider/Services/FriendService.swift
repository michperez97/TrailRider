import Foundation
import FirebaseFirestore

final class FriendService: Sendable {
    static let shared = FriendService()

    private var db: Firestore { Firestore.firestore() }
    private var requestsCollection: CollectionReference { db.collection("friendRequests") }
    private var friendsCollection: CollectionReference { db.collection("friendships") }

    private init() {}

    // MARK: - Search

    /// Search for a user by username
    func searchUser(username: String) async throws -> AppUser? {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username.lowercased())
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.first.flatMap { try? $0.data(as: AppUser.self) }
    }

    // MARK: - Friend Requests

    /// Send a friend request
    func sendRequest(from: AppUser, toUserId: String) async throws {
        let request = FriendRequest(
            fromUserId: from.id ?? "",
            toUserId: toUserId,
            fromUsername: from.username,
            fromDisplayName: from.displayName,
            status: .pending,
            createdAt: Date()
        )
        try await requestsCollection.addDocument(from: request)
    }

    /// Get pending requests sent TO this user
    func getPendingRequests(userId: String) async throws -> [FriendRequest] {
        let snapshot = try await requestsCollection
            .whereField("toUserId", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FriendRequest.self) }
    }

    /// Accept a friend request — creates friendship both ways atomically
    func acceptRequest(_ request: FriendRequest, currentUser: AppUser) async throws {
        guard let requestId = request.id, let currentUserId = currentUser.id else { return }

        let batch = db.batch()

        // Update request status
        batch.updateData(["status": "accepted"], forDocument: requestsCollection.document(requestId))

        // Create friendship: currentUser -> sender
        let friendship1 = Friendship(
            userId: currentUserId,
            friendId: request.fromUserId,
            friendUsername: request.fromUsername,
            friendDisplayName: request.fromDisplayName,
            createdAt: Date()
        )
        try batch.setData(from: friendship1, forDocument: friendsCollection.document())

        // Create friendship: sender -> currentUser
        let friendship2 = Friendship(
            userId: request.fromUserId,
            friendId: currentUserId,
            friendUsername: currentUser.username,
            friendDisplayName: currentUser.displayName,
            createdAt: Date()
        )
        try batch.setData(from: friendship2, forDocument: friendsCollection.document())

        try await batch.commit()
    }

    /// Decline a friend request
    func declineRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else { return }
        try await requestsCollection.document(requestId).updateData(["status": "declined"])
    }

    /// Check if a request already exists between two users
    func requestExists(fromUserId: String, toUserId: String) async throws -> Bool {
        let forward = try await requestsCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("toUserId", isEqualTo: toUserId)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()
        if !forward.documents.isEmpty { return true }

        let reverse = try await requestsCollection
            .whereField("fromUserId", isEqualTo: toUserId)
            .whereField("toUserId", isEqualTo: fromUserId)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments()
        return !reverse.documents.isEmpty
    }

    // MARK: - Friends List

    /// Get all friends for a user
    func getFriends(userId: String) async throws -> [Friendship] {
        let snapshot = try await friendsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Friendship.self) }
    }

    /// Remove a friend (both directions) atomically
    func removeFriend(userId: String, friendId: String) async throws {
        let snapshot1 = try await friendsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("friendId", isEqualTo: friendId)
            .getDocuments()
        let snapshot2 = try await friendsCollection
            .whereField("userId", isEqualTo: friendId)
            .whereField("friendId", isEqualTo: userId)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot1.documents { batch.deleteDocument(doc.reference) }
        for doc in snapshot2.documents { batch.deleteDocument(doc.reference) }
        try await batch.commit()
    }

    /// Check if two users are already friends
    func areFriends(userId: String, friendId: String) async throws -> Bool {
        let snapshot = try await friendsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("friendId", isEqualTo: friendId)
            .limit(to: 1)
            .getDocuments()
        return !snapshot.documents.isEmpty
    }
}
