import Foundation
import FirebaseFirestore
import CoreLocation

final class RideService: Sendable {
    static let shared = RideService()

    private var db: Firestore { Firestore.firestore() }
    private var ridesCollection: CollectionReference { db.collection("rides") }

    private init() {}

    // MARK: - CRUD

    /// Save a new ride
    func saveRide(_ ride: Ride) async throws -> String {
        let ref = try ridesCollection.addDocument(from: ride)
        return ref.documentID
    }

    /// Fetch all rides for a user, newest first
    func getRides(userId: String) async throws -> [Ride] {
        let snapshot = try await ridesCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "startTime", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Ride.self) }
    }

    /// Fetch a single ride
    func getRide(id: String) async throws -> Ride? {
        let snapshot = try await ridesCollection.document(id).getDocument()
        return try snapshot.data(as: Ride.self)
    }

    /// Delete a ride
    func deleteRide(id: String) async throws {
        try await ridesCollection.document(id).delete()
    }
}
