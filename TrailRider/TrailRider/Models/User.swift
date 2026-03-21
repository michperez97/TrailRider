import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var username: String
    var displayName: String
    var avatarURL: String?
    var totalMiles: Double
    var currentStreak: Int
    var isRiding: Bool
    var lastLatitude: Double?
    var lastLongitude: Double?
    var shareLocation: Bool
    var createdAt: Date

    static func new(id: String) -> AppUser {
        AppUser(
            id: id,
            username: "",
            displayName: "",
            avatarURL: nil,
            totalMiles: 0,
            currentStreak: 0,
            isRiding: false,
            lastLatitude: nil,
            lastLongitude: nil,
            shareLocation: false,
            createdAt: Date()
        )
    }
}
