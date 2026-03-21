import Foundation
import FirebaseFirestore

struct CommunityTrail: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var creatorId: String
    var creatorUsername: String
    var name: String
    var description: String
    var difficulty: Difficulty
    var trailType: TrailType
    var direction: Direction
    var features: [String]
    var routeCoordinates: [GeoPoint]
    var distanceMiles: Double
    var parkId: String?
    var photoURLs: [String]
    var conditionReport: ConditionReport?
    var conditionDate: Date?
    var status: Status
    var verificationCount: Int
    var isVerified: Bool
    var flagCount: Int
    var createdAt: Date
    var updatedAt: Date

    enum Difficulty: String, Codable, Sendable, CaseIterable {
        case beginner, intermediate, advanced
    }

    enum TrailType: String, Codable, Sendable, CaseIterable {
        case singletrack, fireRoad = "fire-road", technical
    }

    enum Direction: String, Codable, Sendable, CaseIterable {
        case loop, outAndBack = "out-and-back", oneWay = "one-way"
    }

    enum ConditionReport: String, Codable, Sendable, CaseIterable {
        case dry, muddy, flooded, damaged
    }

    enum Status: String, Codable, Sendable {
        case draft, published
    }

    static let featureOptions = [
        "Jumps", "Drops", "Berms", "Rock Garden",
        "Bridge", "Roots", "Wooden Features"
    ]
}
