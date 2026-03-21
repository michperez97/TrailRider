import Foundation
import FirebaseFirestore

struct Park: Codable, Identifiable, Sendable {
    @DocumentID var id: String?
    var name: String
    var centerLatitude: Double
    var centerLongitude: Double
    var radiusMeters: Double
    var maintainerIds: [String]
    var trailCount: Int
    var createdBy: String
    var createdAt: Date
}
