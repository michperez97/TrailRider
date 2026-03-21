import Foundation
import FirebaseFirestore

struct Bike: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var userId: String
    var name: String
    var type: BikeType
    var brand: String
    var model: String
    var totalMiles: Double

    enum BikeType: String, Codable, CaseIterable, Sendable {
        case trailBike = "Trail"
        case crossCountry = "Cross Country"
        case enduro = "Enduro"
        case downhill = "Downhill"
        case hardtail = "Hardtail"
        case other = "Other"
    }
}
