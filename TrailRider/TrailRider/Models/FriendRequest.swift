import Foundation
import FirebaseFirestore

struct FriendRequest: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var fromUserId: String
    var toUserId: String
    var fromUsername: String
    var fromDisplayName: String
    var status: Status
    var createdAt: Date

    enum Status: String, Codable, Sendable {
        case pending
        case accepted
        case declined
    }
}

struct Friendship: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var userId: String
    var friendId: String
    var friendUsername: String
    var friendDisplayName: String
    var createdAt: Date
}
