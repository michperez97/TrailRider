import Foundation
import FirebaseFirestore

struct GroupSession: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var hostId: String
    var hostDisplayName: String
    var code: String
    var status: Status
    var memberIds: [String]
    var createdAt: Date

    enum Status: String, Codable, Sendable {
        case lobby
        case active
        case ended
    }

    static func generateCode() -> String {
        String(format: "%06d", Int.random(in: 0...999999))
    }
}

struct SessionMember: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var userId: String
    var displayName: String
    var username: String
    var latitude: Double
    var longitude: Double
    var speed: Double
    var distanceMiles: Double
    var isReady: Bool
    var shareLocation: Bool
}
