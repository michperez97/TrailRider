import Foundation
import FirebaseFirestore
import CoreLocation

struct Trail: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var name: String
    var city: String
    var state: String
    var latitude: Double
    var longitude: Double
    var tier: TrailTier
    var totalMiles: Double
    var difficultyLevels: [String]
    var parkingFee: String?
    var hours: String?
    var currentCondition: ConditionStatus
    var activeRiderCount: Int
    var description: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum TrailTier: String, Codable, Sendable {
        case featured, community, userSubmitted
    }

    enum ConditionStatus: String, Codable, Sendable {
        case dry, muddy, flooded
    }
}
