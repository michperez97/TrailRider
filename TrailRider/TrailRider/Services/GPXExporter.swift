import Foundation
import CoreLocation

struct TrailSegmentRecording: Identifiable {
    let id = UUID()
    var name: String?
    var coordinates: [(CLLocationCoordinate2D, Date)]
    var startTime: Date
    var endTime: Date?

    var distanceMiles: Double {
        var total: Double = 0
        for i in 1..<coordinates.count {
            let prev = CLLocation(latitude: coordinates[i-1].0.latitude, longitude: coordinates[i-1].0.longitude)
            let curr = CLLocation(latitude: coordinates[i].0.latitude, longitude: coordinates[i].0.longitude)
            total += curr.distance(from: prev)
        }
        return total / 1609.344
    }

    var durationSeconds: Int {
        guard let end = endTime else { return 0 }
        return Int(end.timeIntervalSince(startTime))
    }

    var formattedDistance: String {
        String(format: "%.2f mi", distanceMiles)
    }

    var formattedDuration: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct GPXExporter {

    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func export(segments: [TrailSegmentRecording], to directory: URL) throws -> [URL] {
        var urls: [URL] = []
        let formatter = ISO8601DateFormatter()

        for (index, segment) in segments.enumerated() {
            let name = segment.name ?? "segment-\(String(format: "%02d", index + 1))"
            let safeName = name.replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let fileName = "\(safeName).gpx"
            let fileURL = directory.appendingPathComponent(fileName)
            let gpx = buildGPX(name: name, coordinates: segment.coordinates, formatter: formatter)
            try gpx.write(to: fileURL, atomically: true, encoding: .utf8)
            urls.append(fileURL)
        }
        return urls
    }

    private static func buildGPX(
        name: String,
        coordinates: [(CLLocationCoordinate2D, Date)],
        formatter: ISO8601DateFormatter
    ) -> String {
        var parts: [String] = []
        parts.reserveCapacity(coordinates.count + 4)
        parts.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TrailRider" xmlns="http://www.topografix.com/GPX/1/1">
        <trk>
        <name>\(xmlEscape(name))</name>
        <trkseg>
        """)
        for (coord, time) in coordinates {
            let iso = formatter.string(from: time)
            parts.append("<trkpt lat=\"\(coord.latitude)\" lon=\"\(coord.longitude)\"><time>\(iso)</time></trkpt>")
        }
        parts.append("</trkseg>\n</trk>\n</gpx>")
        return parts.joined(separator: "\n")
    }
}
