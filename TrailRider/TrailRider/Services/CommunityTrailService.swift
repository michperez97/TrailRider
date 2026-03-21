import Foundation
import FirebaseFirestore
import CoreLocation

final class CommunityTrailService: Sendable {
    static let shared = CommunityTrailService()

    private var db: Firestore { Firestore.firestore() }
    private var trailsCollection: CollectionReference { db.collection("communityTrails") }
    private var parksCollection: CollectionReference { db.collection("parks") }

    private init() {}

    // MARK: - Trail CRUD

    /// Save a new draft trail, returns the document ID
    func saveDraft(_ trail: CommunityTrail) async throws -> String {
        let ref = try trailsCollection.addDocument(from: trail)
        return ref.documentID
    }

    /// Publish a draft trail by setting status to published
    func publishTrail(id: String) async throws {
        try await trailsCollection.document(id).updateData([
            "status": CommunityTrail.Status.published.rawValue,
            "updatedAt": Date()
        ])
    }

    /// Get all drafts for a user, newest first
    func getDrafts(userId: String) async throws -> [CommunityTrail] {
        let snapshot = try await trailsCollection
            .whereField("creatorId", isEqualTo: userId)
            .whereField("status", isEqualTo: CommunityTrail.Status.draft.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CommunityTrail.self) }
    }

    /// Get published trails for a specific park
    func getPublishedTrails(parkId: String) async throws -> [CommunityTrail] {
        let snapshot = try await trailsCollection
            .whereField("parkId", isEqualTo: parkId)
            .whereField("status", isEqualTo: CommunityTrail.Status.published.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CommunityTrail.self) }
    }

    /// Get all published trails, ordered by most verified first
    func getAllPublishedTrails() async throws -> [CommunityTrail] {
        let snapshot = try await trailsCollection
            .whereField("status", isEqualTo: CommunityTrail.Status.published.rawValue)
            .order(by: "verificationCount", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: CommunityTrail.self) }
    }

    /// Fetch a single trail by ID
    func getTrail(id: String) async throws -> CommunityTrail? {
        let document = try await trailsCollection.document(id).getDocument()
        guard document.exists else { return nil }
        return try document.data(as: CommunityTrail.self)
    }

    /// Update specific fields on a trail
    func updateTrail(id: String, fields: [String: Any]) async throws {
        try await trailsCollection.document(id).updateData(fields)
    }

    /// Delete a draft trail
    func deleteDraft(id: String) async throws {
        try await trailsCollection.document(id).delete()
    }

    // MARK: - Park Methods

    /// Fetch all parks
    func getParks() async throws -> [Park] {
        let snapshot = try await parksCollection.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Park.self) }
    }

    /// Find a park that contains the given coordinate (within its radius)
    func findPark(latitude: Double, longitude: Double) async throws -> Park? {
        let parks = try await getParks()
        let location = CLLocation(latitude: latitude, longitude: longitude)

        return parks.first { park in
            let parkCenter = CLLocation(latitude: park.centerLatitude, longitude: park.centerLongitude)
            let distance = location.distance(from: parkCenter)
            return distance <= park.radiusMeters
        }
    }

    /// Create a new park, returns the document ID
    func createPark(_ park: Park) async throws -> String {
        let ref = try parksCollection.addDocument(from: park)
        return ref.documentID
    }

    /// Add a maintainer to a park
    func addMaintainer(parkId: String, userId: String) async throws {
        try await parksCollection.document(parkId).updateData([
            "maintainerIds": FieldValue.arrayUnion([userId])
        ])
    }

    /// Count how many trails a user has created in a specific park
    func getUserTrailCount(userId: String, parkId: String) async throws -> Int {
        let snapshot = try await trailsCollection
            .whereField("creatorId", isEqualTo: userId)
            .whereField("parkId", isEqualTo: parkId)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }

    // MARK: - Verification Methods

    /// Confirm a trail exists (community verification). Uses WriteBatch for atomicity.
    func confirmTrail(trailId: String, userId: String) async throws {
        let batch = db.batch()

        // Create confirmation doc with userId as document ID
        let confirmationRef = trailsCollection.document(trailId)
            .collection("confirmations").document(userId)
        let confirmation = TrailConfirmation(userId: userId, confirmedAt: Date())
        try batch.setData(from: confirmation, forDocument: confirmationRef)

        // Increment verification count
        let trailRef = trailsCollection.document(trailId)
        batch.updateData([
            "verificationCount": FieldValue.increment(Int64(1))
        ], forDocument: trailRef)

        // Check current count to decide if trail should be marked verified
        let trailDoc = try await trailRef.getDocument()
        let currentCount = trailDoc.data()?["verificationCount"] as? Int ?? 0
        if currentCount + 1 >= 3 {
            batch.updateData([
                "isVerified": true
            ], forDocument: trailRef)
        }

        try await batch.commit()
    }

    /// Check if a user has already confirmed a trail
    func hasConfirmed(trailId: String, userId: String) async throws -> Bool {
        let doc = try await trailsCollection.document(trailId)
            .collection("confirmations").document(userId)
            .getDocument()
        return doc.exists
    }

    // MARK: - Edit Methods

    /// Submit a proposed edit for a trail
    func submitEdit(_ edit: TrailEdit, trailId: String) async throws {
        let editsCollection = trailsCollection.document(trailId).collection("edits")
        _ = try editsCollection.addDocument(from: edit)
    }

    /// Get all pending edits for a trail
    func getPendingEdits(trailId: String) async throws -> [TrailEdit] {
        let snapshot = try await trailsCollection.document(trailId)
            .collection("edits")
            .whereField("status", isEqualTo: TrailEdit.Status.pending.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: TrailEdit.self) }
    }

    /// Get all pending edits across all trails owned by a user.
    /// Returns only trails that have at least one pending edit.
    func getPendingEditsForCreator(userId: String) async throws -> [(CommunityTrail, [TrailEdit])] {
        // First get all the user's published trails
        let snapshot = try await trailsCollection
            .whereField("creatorId", isEqualTo: userId)
            .whereField("status", isEqualTo: CommunityTrail.Status.published.rawValue)
            .getDocuments()
        let trails = snapshot.documents.compactMap { try? $0.data(as: CommunityTrail.self) }

        var results: [(CommunityTrail, [TrailEdit])] = []
        for trail in trails {
            guard let trailId = trail.id else { continue }
            let edits = try await getPendingEdits(trailId: trailId)
            if !edits.isEmpty {
                results.append((trail, edits))
            }
        }
        return results
    }

    /// Approve an edit: apply changes to the trail and mark the edit as approved. Uses WriteBatch.
    func approveEdit(trailId: String, editId: String, changes: [String: String], reviewerId: String) async throws {
        let batch = db.batch()

        // Apply the changes to the trail
        let trailRef = trailsCollection.document(trailId)
        var trailUpdates: [String: Any] = [:]
        for (key, value) in changes {
            trailUpdates[key] = value
        }
        trailUpdates["updatedAt"] = Date()
        batch.updateData(trailUpdates, forDocument: trailRef)

        // Mark the edit as approved
        let editRef = trailsCollection.document(trailId).collection("edits").document(editId)
        batch.updateData([
            "status": TrailEdit.Status.approved.rawValue,
            "reviewedBy": reviewerId
        ], forDocument: editRef)

        try await batch.commit()
    }

    /// Reject an edit
    func rejectEdit(trailId: String, editId: String, reviewerId: String) async throws {
        try await trailsCollection.document(trailId).collection("edits").document(editId).updateData([
            "status": TrailEdit.Status.rejected.rawValue,
            "reviewedBy": reviewerId
        ])
    }

    // MARK: - Seeding

    /// Seed Miami parks if the parks collection is empty
    func seedMiamiParks() async throws {
        let snapshot = try await parksCollection.getDocuments()
        guard snapshot.documents.isEmpty else { return }

        let ameliaEarhart = Park(
            name: "Amelia Earhart Park",
            centerLatitude: 25.8844,
            centerLongitude: -80.2789,
            radiusMeters: 800,
            maintainerIds: [],
            trailCount: 0,
            createdBy: "system",
            createdAt: Date()
        )

        let virginiaKey = Park(
            name: "Virginia Key",
            centerLatitude: 25.7430,
            centerLongitude: -80.1540,
            radiusMeters: 1000,
            maintainerIds: [],
            trailCount: 0,
            createdBy: "system",
            createdAt: Date()
        )

        _ = try parksCollection.addDocument(from: ameliaEarhart)
        _ = try parksCollection.addDocument(from: virginiaKey)
    }
}
