import Foundation
import FirebaseFirestore

final class GroupRideService: Sendable {
    static let shared = GroupRideService()

    private var db: Firestore { Firestore.firestore() }
    private var sessionsCollection: CollectionReference { db.collection("groupSessions") }

    private init() {}

    private func membersCollection(sessionId: String) -> CollectionReference {
        sessionsCollection.document(sessionId).collection("members")
    }

    // MARK: - Session CRUD

    /// Create a new group session
    func createSession(host: AppUser) async throws -> GroupSession {
        guard let hostId = host.id, !hostId.isEmpty else {
            throw NSError(domain: "GroupRideService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid host user"])
        }

        // Generate unique code — retry if collision
        var code = GroupSession.generateCode()
        for _ in 0..<5 {
            if try await findSession(code: code) == nil { break }
            code = GroupSession.generateCode()
        }

        var session = GroupSession(
            hostId: hostId,
            hostDisplayName: host.displayName,
            code: code,
            status: .lobby,
            memberIds: [hostId],
            createdAt: Date()
        )
        let ref = try sessionsCollection.addDocument(from: session)
        session.id = ref.documentID

        let member = SessionMember(
            userId: hostId,
            displayName: host.displayName,
            username: host.username,
            latitude: 0,
            longitude: 0,
            speed: 0,
            distanceMiles: 0,
            isReady: true,
            shareLocation: host.shareLocation
        )
        try membersCollection(sessionId: ref.documentID).document(hostId).setData(from: member)

        return session
    }

    /// Find session by join code
    func findSession(code: String) async throws -> GroupSession? {
        let snapshot = try await sessionsCollection
            .whereField("code", isEqualTo: code)
            .whereField("status", isEqualTo: "lobby")
            .limit(to: 1)
            .getDocuments()
        return snapshot.documents.first.flatMap { try? $0.data(as: GroupSession.self) }
    }

    /// Join an existing session
    func joinSession(sessionId: String, user: AppUser) async throws {
        guard let userId = user.id, !userId.isEmpty else {
            throw NSError(domain: "GroupRideService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid user"])
        }

        try await sessionsCollection.document(sessionId).updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])

        let member = SessionMember(
            userId: userId,
            displayName: user.displayName,
            username: user.username,
            latitude: 0,
            longitude: 0,
            speed: 0,
            distanceMiles: 0,
            isReady: false,
            shareLocation: user.shareLocation
        )
        try membersCollection(sessionId: sessionId).document(userId).setData(from: member)
    }

    /// Start the session (host only)
    func startSession(sessionId: String) async throws {
        try await sessionsCollection.document(sessionId).updateData(["status": "active"])
    }

    /// End the session
    func endSession(sessionId: String) async throws {
        try await sessionsCollection.document(sessionId).updateData(["status": "ended"])
    }

    /// Leave a session
    func leaveSession(sessionId: String, userId: String) async throws {
        try await sessionsCollection.document(sessionId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])
        try await membersCollection(sessionId: sessionId).document(userId).delete()
    }

    /// Toggle ready status
    func setReady(sessionId: String, userId: String, isReady: Bool) async throws {
        try await membersCollection(sessionId: sessionId).document(userId).updateData([
            "isReady": isReady
        ])
    }

    // MARK: - Live Location

    /// Update member's live location
    func updateLocation(sessionId: String, userId: String, latitude: Double, longitude: Double, speed: Double, distance: Double) async throws {
        try await membersCollection(sessionId: sessionId).document(userId).updateData([
            "latitude": latitude,
            "longitude": longitude,
            "speed": speed,
            "distanceMiles": distance
        ])
    }

    // MARK: - Listeners

    /// Listen to session changes
    func listenToSession(sessionId: String, onChange: @escaping (GroupSession?) -> Void) -> ListenerRegistration {
        sessionsCollection.document(sessionId).addSnapshotListener { snapshot, _ in
            let session = try? snapshot?.data(as: GroupSession.self)
            onChange(session)
        }
    }

    /// Listen to member changes
    func listenToMembers(sessionId: String, onChange: @escaping ([SessionMember]) -> Void) -> ListenerRegistration {
        membersCollection(sessionId: sessionId).addSnapshotListener { snapshot, _ in
            let members = snapshot?.documents.compactMap { try? $0.data(as: SessionMember.self) } ?? []
            onChange(members)
        }
    }
}
