import Foundation
import FirebaseFirestore

struct TrailEdit: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var proposerId: String
    var proposerUsername: String
    var changes: [String: String]
    var status: Status
    var reviewedBy: String?
    var createdAt: Date

    enum Status: String, Codable, Sendable {
        case pending, approved, rejected
    }
}

struct TrailConfirmation: Codable, Sendable {
    var userId: String
    var confirmedAt: Date
}
