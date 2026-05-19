import Foundation
import FirebaseFirestore

enum StandaloneWatchRidePayload {
    enum PayloadError: LocalizedError {
        case missingRequiredField

        var errorDescription: String? {
            switch self {
            case .missingRequiredField:
                return "Watch ride payload is missing required fields."
            }
        }
    }

    static func ride(from data: [String: Any], userId: String) throws -> Ride {
        guard let startTs = timeInterval(from: data["startTime"]),
              let endTs = timeInterval(from: data["endTime"]),
              let duration = int(from: data["durationSeconds"]),
              let distMeters = double(from: data["distanceMeters"]) else {
            throw PayloadError.missingRequiredField
        }

        let miles = distMeters / 1609.344
        let avg = duration > 0 ? miles / (Double(duration) / 3600.0) : 0

        return Ride(
            userId: userId,
            startTime: Date(timeIntervalSince1970: startTs),
            endTime: Date(timeIntervalSince1970: endTs),
            durationSeconds: duration,
            distanceMiles: miles,
            maxSpeedMph: 0,
            avgSpeedMph: avg,
            elevationGainFeet: 0,
            routePolyline: routeCoordinates(from: data["routeCoordinates"]),
            photoURLs: []
        )
    }

    private static func routeCoordinates(from value: Any?) -> [GeoPoint] {
        if let coordinates = value as? [[String: Double]] {
            return coordinates.compactMap { coordinate in
                guard let lat = coordinate["lat"], let lon = coordinate["lon"] else { return nil }
                return GeoPoint(latitude: lat, longitude: lon)
            }
        }

        guard let coordinates = value as? [[String: Any]] else { return [] }
        return coordinates.compactMap { coordinate in
            guard let lat = double(from: coordinate["lat"]), let lon = double(from: coordinate["lon"]) else {
                return nil
            }
            return GeoPoint(latitude: lat, longitude: lon)
        }
    }

    private static func timeInterval(from value: Any?) -> TimeInterval? {
        double(from: value)
    }

    private static func int(from value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let double as Double:
            return Int(double)
        default:
            return nil
        }
    }

    private static func double(from value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let number as NSNumber:
            return number.doubleValue
        case let int as Int:
            return Double(int)
        default:
            return nil
        }
    }
}
