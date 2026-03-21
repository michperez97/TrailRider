import Foundation
import CoreLocation
import SwiftUI

/// Approximate trail route coordinates for featured trails.
/// Replace with actual GPX data when available.
struct TrailMapData {

    // MARK: - Amelia Earhart Park
    // 7.75 miles of singletrack — XC loops through the park
    // Center: 25.8927, -80.2833 — Real GPX data from Trailforks where available
    static let ameliaEarhartRoutes: [TrailRoute] = [
        // Real GPX data from Trailforks
        TrailRoute(name: "Trailhead Corridor", difficulty: "Beginner", color: .green, coordinates: [
            CLLocationCoordinate2D(latitude: 25.89365, longitude: -80.28009),
            CLLocationCoordinate2D(latitude: 25.89342, longitude: -80.27988),
            CLLocationCoordinate2D(latitude: 25.89321, longitude: -80.27966),
            CLLocationCoordinate2D(latitude: 25.89306, longitude: -80.27950),
            CLLocationCoordinate2D(latitude: 25.89296, longitude: -80.27941),
            CLLocationCoordinate2D(latitude: 25.89284, longitude: -80.27929),
            CLLocationCoordinate2D(latitude: 25.89272, longitude: -80.27915),
            CLLocationCoordinate2D(latitude: 25.89240, longitude: -80.27880),
            CLLocationCoordinate2D(latitude: 25.89215, longitude: -80.27854),
            CLLocationCoordinate2D(latitude: 25.89204, longitude: -80.27843),
            CLLocationCoordinate2D(latitude: 25.89193, longitude: -80.27836),
            CLLocationCoordinate2D(latitude: 25.89179, longitude: -80.27831),
            CLLocationCoordinate2D(latitude: 25.89166, longitude: -80.27832),
        ]),
        // Approximate routes — replace with GPX data when available
        TrailRoute(name: "Potato Vine", difficulty: "Beginner", color: .green, coordinates: [
            CLLocationCoordinate2D(latitude: 25.89166, longitude: -80.27832),
            CLLocationCoordinate2D(latitude: 25.89148, longitude: -80.27840),
            CLLocationCoordinate2D(latitude: 25.89130, longitude: -80.27855),
            CLLocationCoordinate2D(latitude: 25.89115, longitude: -80.27875),
            CLLocationCoordinate2D(latitude: 25.89105, longitude: -80.27900),
            CLLocationCoordinate2D(latitude: 25.89100, longitude: -80.27928),
            CLLocationCoordinate2D(latitude: 25.89108, longitude: -80.27955),
            CLLocationCoordinate2D(latitude: 25.89125, longitude: -80.27975),
            CLLocationCoordinate2D(latitude: 25.89148, longitude: -80.27988),
        ]),
        TrailRoute(name: "Coffee Trail", difficulty: "Intermediate", color: .blue, coordinates: [
            CLLocationCoordinate2D(latitude: 25.89148, longitude: -80.27988),
            CLLocationCoordinate2D(latitude: 25.89160, longitude: -80.28010),
            CLLocationCoordinate2D(latitude: 25.89175, longitude: -80.28035),
            CLLocationCoordinate2D(latitude: 25.89195, longitude: -80.28055),
            CLLocationCoordinate2D(latitude: 25.89220, longitude: -80.28070),
            CLLocationCoordinate2D(latitude: 25.89250, longitude: -80.28078),
            CLLocationCoordinate2D(latitude: 25.89280, longitude: -80.28075),
            CLLocationCoordinate2D(latitude: 25.89305, longitude: -80.28060),
            CLLocationCoordinate2D(latitude: 25.89325, longitude: -80.28040),
            CLLocationCoordinate2D(latitude: 25.89340, longitude: -80.28020),
            CLLocationCoordinate2D(latitude: 25.89365, longitude: -80.28009),
        ]),
        TrailRoute(name: "Gobble Gobble", difficulty: "Intermediate", color: .blue, coordinates: [
            CLLocationCoordinate2D(latitude: 25.89100, longitude: -80.27928),
            CLLocationCoordinate2D(latitude: 25.89085, longitude: -80.27945),
            CLLocationCoordinate2D(latitude: 25.89065, longitude: -80.27965),
            CLLocationCoordinate2D(latitude: 25.89048, longitude: -80.27980),
            CLLocationCoordinate2D(latitude: 25.89035, longitude: -80.27998),
            CLLocationCoordinate2D(latitude: 25.89028, longitude: -80.28018),
            CLLocationCoordinate2D(latitude: 25.89035, longitude: -80.28038),
            CLLocationCoordinate2D(latitude: 25.89050, longitude: -80.28050),
            CLLocationCoordinate2D(latitude: 25.89070, longitude: -80.28055),
        ]),
        TrailRoute(name: "Chupacabra", difficulty: "Advanced", color: .black, coordinates: [
            CLLocationCoordinate2D(latitude: 25.89070, longitude: -80.28055),
            CLLocationCoordinate2D(latitude: 25.89055, longitude: -80.28068),
            CLLocationCoordinate2D(latitude: 25.89038, longitude: -80.28075),
            CLLocationCoordinate2D(latitude: 25.89020, longitude: -80.28070),
            CLLocationCoordinate2D(latitude: 25.89005, longitude: -80.28055),
            CLLocationCoordinate2D(latitude: 25.88995, longitude: -80.28035),
            CLLocationCoordinate2D(latitude: 25.88998, longitude: -80.28012),
            CLLocationCoordinate2D(latitude: 25.89010, longitude: -80.27995),
            CLLocationCoordinate2D(latitude: 25.89028, longitude: -80.27985),
        ]),
        TrailRoute(name: "Golden Gate", difficulty: "Advanced", color: .black, coordinates: [
            CLLocationCoordinate2D(latitude: 25.89028, longitude: -80.27985),
            CLLocationCoordinate2D(latitude: 25.89015, longitude: -80.27968),
            CLLocationCoordinate2D(latitude: 25.89000, longitude: -80.27948),
            CLLocationCoordinate2D(latitude: 25.88988, longitude: -80.27930),
            CLLocationCoordinate2D(latitude: 25.88980, longitude: -80.27910),
            CLLocationCoordinate2D(latitude: 25.88985, longitude: -80.27890),
            CLLocationCoordinate2D(latitude: 25.89000, longitude: -80.27878),
            CLLocationCoordinate2D(latitude: 25.89020, longitude: -80.27875),
        ]),
    ]

    // MARK: - Virginia Key North Point
    // 10 miles of singletrack — island trails along Biscayne Bay
    static let virginiaKeyRoutes: [TrailRoute] = [
        TrailRoute(name: "Main Loop", difficulty: "Green", color: .green, coordinates: [
            CLLocationCoordinate2D(latitude: 25.7445, longitude: -80.1555),
            CLLocationCoordinate2D(latitude: 25.7450, longitude: -80.1548),
            CLLocationCoordinate2D(latitude: 25.7458, longitude: -80.1540),
            CLLocationCoordinate2D(latitude: 25.7465, longitude: -80.1530),
            CLLocationCoordinate2D(latitude: 25.7470, longitude: -80.1518),
            CLLocationCoordinate2D(latitude: 25.7472, longitude: -80.1505),
            CLLocationCoordinate2D(latitude: 25.7468, longitude: -80.1492),
            CLLocationCoordinate2D(latitude: 25.7460, longitude: -80.1483),
            CLLocationCoordinate2D(latitude: 25.7450, longitude: -80.1478),
            CLLocationCoordinate2D(latitude: 25.7440, longitude: -80.1480),
            CLLocationCoordinate2D(latitude: 25.7432, longitude: -80.1488),
            CLLocationCoordinate2D(latitude: 25.7425, longitude: -80.1498),
            CLLocationCoordinate2D(latitude: 25.7422, longitude: -80.1510),
            CLLocationCoordinate2D(latitude: 25.7423, longitude: -80.1525),
            CLLocationCoordinate2D(latitude: 25.7428, longitude: -80.1538),
            CLLocationCoordinate2D(latitude: 25.7435, longitude: -80.1548),
            CLLocationCoordinate2D(latitude: 25.7442, longitude: -80.1553),
            CLLocationCoordinate2D(latitude: 25.7445, longitude: -80.1555),
        ]),
        TrailRoute(name: "War Pigs", difficulty: "Black Diamond", color: .black, coordinates: [
            CLLocationCoordinate2D(latitude: 25.7465, longitude: -80.1530),
            CLLocationCoordinate2D(latitude: 25.7468, longitude: -80.1525),
            CLLocationCoordinate2D(latitude: 25.7472, longitude: -80.1518),
            CLLocationCoordinate2D(latitude: 25.7475, longitude: -80.1510),
            CLLocationCoordinate2D(latitude: 25.7478, longitude: -80.1502),
            CLLocationCoordinate2D(latitude: 25.7480, longitude: -80.1495),
            CLLocationCoordinate2D(latitude: 25.7478, longitude: -80.1488),
            CLLocationCoordinate2D(latitude: 25.7473, longitude: -80.1485),
            CLLocationCoordinate2D(latitude: 25.7468, longitude: -80.1488),
            CLLocationCoordinate2D(latitude: 25.7468, longitude: -80.1492),
        ]),
        TrailRoute(name: "Tom Sawyer", difficulty: "Blue", color: .blue, coordinates: [
            CLLocationCoordinate2D(latitude: 25.7450, longitude: -80.1478),
            CLLocationCoordinate2D(latitude: 25.7448, longitude: -80.1470),
            CLLocationCoordinate2D(latitude: 25.7445, longitude: -80.1462),
            CLLocationCoordinate2D(latitude: 25.7440, longitude: -80.1455),
            CLLocationCoordinate2D(latitude: 25.7435, longitude: -80.1452),
            CLLocationCoordinate2D(latitude: 25.7430, longitude: -80.1458),
            CLLocationCoordinate2D(latitude: 25.7428, longitude: -80.1468),
            CLLocationCoordinate2D(latitude: 25.7430, longitude: -80.1478),
            CLLocationCoordinate2D(latitude: 25.7432, longitude: -80.1488),
        ]),
        TrailRoute(name: "Jimbo", difficulty: "Blue", color: .blue, coordinates: [
            CLLocationCoordinate2D(latitude: 25.7440, longitude: -80.1480),
            CLLocationCoordinate2D(latitude: 25.7437, longitude: -80.1475),
            CLLocationCoordinate2D(latitude: 25.7433, longitude: -80.1468),
            CLLocationCoordinate2D(latitude: 25.7428, longitude: -80.1462),
            CLLocationCoordinate2D(latitude: 25.7423, longitude: -80.1460),
            CLLocationCoordinate2D(latitude: 25.7418, longitude: -80.1465),
            CLLocationCoordinate2D(latitude: 25.7418, longitude: -80.1475),
            CLLocationCoordinate2D(latitude: 25.7420, longitude: -80.1485),
            CLLocationCoordinate2D(latitude: 25.7425, longitude: -80.1498),
        ]),
        TrailRoute(name: "Coastal Path", difficulty: "Green", color: .green, coordinates: [
            CLLocationCoordinate2D(latitude: 25.7472, longitude: -80.1505),
            CLLocationCoordinate2D(latitude: 25.7475, longitude: -80.1498),
            CLLocationCoordinate2D(latitude: 25.7478, longitude: -80.1490),
            CLLocationCoordinate2D(latitude: 25.7480, longitude: -80.1482),
            CLLocationCoordinate2D(latitude: 25.7478, longitude: -80.1475),
            CLLocationCoordinate2D(latitude: 25.7473, longitude: -80.1470),
            CLLocationCoordinate2D(latitude: 25.7465, longitude: -80.1472),
            CLLocationCoordinate2D(latitude: 25.7460, longitude: -80.1478),
            CLLocationCoordinate2D(latitude: 25.7460, longitude: -80.1483),
        ]),
    ]

    static func routes(for trailId: String) -> [TrailRoute] {
        switch trailId {
        case "amelia-earhart": return ameliaEarhartRoutes
        case "virginia-key": return virginiaKeyRoutes
        default: return []
        }
    }
}

struct TrailRoute: Identifiable {
    let id: String
    let name: String
    let difficulty: String
    let color: TrailColor
    let coordinates: [CLLocationCoordinate2D]

    init(name: String, difficulty: String, color: TrailColor, coordinates: [CLLocationCoordinate2D]) {
        self.id = name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.difficulty = difficulty
        self.color = color
        self.coordinates = coordinates
    }

    enum TrailColor {
        case green, blue, black, red

        var swiftUIColor: Color {
            switch self {
            case .green: return .green
            case .blue: return .blue
            case .black: return .primary
            case .red: return .red
            }
        }
    }
}
