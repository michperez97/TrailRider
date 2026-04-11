import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

final class RideService: Sendable {
    static let shared = RideService()

    private var db: Firestore { Firestore.firestore() }
    private var ridesCollection: CollectionReference { db.collection("rides") }

    private init() {}

    // MARK: - CRUD

    /// Save a new ride (atomic: ride doc + totalMiles update in one batch)
    func saveRide(_ ride: Ride) async throws -> String {
        let ref = ridesCollection.document()
        let userRef = db.collection("users").document(ride.userId)

        let batch = db.batch()
        try batch.setData(from: ride, forDocument: ref)
        batch.updateData(["totalMiles": FieldValue.increment(ride.distanceMiles)], forDocument: userRef)
        try await batch.commit()

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

    /// Delete a ride (atomic: remove doc + decrement totalMiles in one batch)
    func deleteRide(id: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "RideService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let rideRef = ridesCollection.document(id)
        let snapshot = try await rideRef.getDocument()
        guard let ride = try? snapshot.data(as: Ride.self), ride.userId == currentUid else {
            throw NSError(domain: "RideService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Not authorized to delete this ride"])
        }

        let userRef = db.collection("users").document(ride.userId)
        let batch = db.batch()
        batch.deleteDocument(rideRef)
        batch.updateData(["totalMiles": FieldValue.increment(-ride.distanceMiles)], forDocument: userRef)
        try await batch.commit()
    }

    /// Check if a ride with the given userId and startTime already exists
    func rideExists(userId: String, startTime: Date) async throws -> Bool {
        let snapshot = try await ridesCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("startTime", isEqualTo: startTime)
            .limit(to: 1)
            .getDocuments()
        return !snapshot.documents.isEmpty
    }
}
