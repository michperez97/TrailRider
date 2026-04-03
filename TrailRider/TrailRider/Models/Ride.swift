import Foundation
import FirebaseFirestore
import CoreLocation

struct Ride: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var userId: String
    var bikeId: String?
    var trailId: String?
    var startTime: Date
    var endTime: Date?
    var durationSeconds: Int
    var distanceMiles: Double
    var maxSpeedMph: Double
    var avgSpeedMph: Double
    var elevationGainFeet: Double
    var routePolyline: [GeoPoint]
    var conditionReport: TrailCondition?
    var photoURLs: [String]

    enum TrailCondition: String, Codable, Sendable {
        case dry, muddy, flooded, damaged
    }

    struct RoutePoint: Codable, Sendable {
        let latitude: Double
        let longitude: Double
        let altitude: Double
        let timestamp: Double
        let speed: Double
        let heartRate: Double?
    }

    var routePoints: [RoutePoint]?
}
