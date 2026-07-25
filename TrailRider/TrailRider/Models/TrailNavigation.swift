import CoreLocation
import CoreGraphics
import Foundation

enum LocationSignalQuality: String {
    case unknown
    case strong
    case usable
    case weak
    case stale

    var label: String {
        switch self {
        case .unknown: "GPS acquiring"
        case .strong: "GPS strong"
        case .usable: "GPS usable"
        case .weak: "GPS weak"
        case .stale: "GPS stale"
        }
    }
}

enum TrailNavigationConfidence: String {
    case unknown
    case high
    case medium
    case low
    case offRoute

    var label: String {
        switch self {
        case .unknown: "Finding trail"
        case .high: "On trail"
        case .medium: "Likely on trail"
        case .low: "Trail match weak"
        case .offRoute: "Off route"
        }
    }
}

struct RideNavigationCue {
    enum Kind {
        case fork
        case curveLeft
        case curveRight
        case technical
        case offRoute
        case gpsWeak
    }

    let kind: Kind
    let title: String
    let detail: String
    let distanceMeters: CLLocationDistance?

    var iconName: String {
        switch kind {
        case .fork: "arrow.triangle.branch"
        case .curveLeft: "arrow.turn.up.left"
        case .curveRight: "arrow.turn.up.right"
        case .technical: "exclamationmark.triangle.fill"
        case .offRoute: "location.slash.fill"
        case .gpsWeak: "antenna.radiowaves.left.and.right.slash"
        }
    }

    var distanceText: String {
        guard let distanceMeters else { return "" }
        return trailDistanceText(for: distanceMeters)
    }
}

enum TrailForkDirection: String {
    case straight
    case slightLeft
    case left
    case hardLeft
    case slightRight
    case right
    case hardRight
    case back

    var label: String {
        switch self {
        case .straight: "straight"
        case .slightLeft: "slight left"
        case .left: "left"
        case .hardLeft: "hard left"
        case .slightRight: "slight right"
        case .right: "right"
        case .hardRight: "hard right"
        case .back: "back"
        }
    }

    var iconName: String {
        switch self {
        case .straight: "arrow.up"
        case .slightLeft: "arrow.up.left"
        case .left, .hardLeft: "arrow.turn.up.left"
        case .slightRight: "arrow.up.right"
        case .right, .hardRight: "arrow.turn.up.right"
        case .back: "arrow.uturn.down"
        }
    }
}

struct TrailForkChoice: Identifiable {
    let id: String
    let trailName: String
    let difficulty: String
    let direction: TrailForkDirection
    let bearingDegrees: CLLocationDirection
    let distanceMeters: CLLocationDistance

    var displayText: String {
        "\(trailName) \(direction.label)"
    }
}

struct TrailNavigationState {
    var currentTrailName: String
    var currentDifficulty: String
    var parkName: String
    var statusText: String
    var confidence: TrailNavigationConfidence
    var signalQuality: LocationSignalQuality
    var progressFraction: Double
    var directionalProgressFraction: Double
    var distanceAlongSegmentMeters: CLLocationDistance
    var remainingSegmentMeters: CLLocationDistance
    var distanceToTrailMeters: CLLocationDistance?
    var lookaheadMeters: CLLocationDistance
    var matchedCoordinate: CLLocationCoordinate2D?
    var currentSegmentCoordinates: [CLLocationCoordinate2D]
    var visibleAheadCoordinates: [CLLocationCoordinate2D]
    var upcomingForkChoices: [TrailForkChoice]
    var cue: RideNavigationCue?

    static let idle = TrailNavigationState(
        currentTrailName: "Finding trail",
        currentDifficulty: "",
        parkName: "",
        statusText: "Start moving for trail guidance",
        confidence: .unknown,
        signalQuality: .unknown,
        progressFraction: 0,
        directionalProgressFraction: 0,
        distanceAlongSegmentMeters: 0,
        remainingSegmentMeters: 0,
        distanceToTrailMeters: nil,
        lookaheadMeters: 220,
        matchedCoordinate: nil,
        currentSegmentCoordinates: [],
        visibleAheadCoordinates: [],
        upcomingForkChoices: [],
        cue: nil
    )

    var hasTrailMatch: Bool {
        confidence != .unknown && confidence != .offRoute
    }

    var progressPercentText: String {
        "\(Int((directionalProgressFraction * 100).rounded()))%"
    }

    var remainingSegmentText: String {
        trailDistanceText(for: remainingSegmentMeters)
    }
}

/// Formats a metric distance as feet below a tenth of a mile, else miles.
func trailDistanceText(for meters: CLLocationDistance) -> String {
    let feet = meters * 3.28084
    if feet < 528 {
        return "\(Int(feet.rounded())) ft"
    }
    return String(format: "%.1f mi", meters / 1609.344)
}

struct TrailGraph {
    let segments: [TrailSegment]
    let nodes: [TrailNode]

    init(segments: [TrailSegment]) {
        self.segments = segments
        self.nodes = Self.buildNodes(from: segments)
    }

    static func featuredTrailGraph() -> TrailGraph {
        let amelia = TrailMapData.routes(for: "amelia-earhart").map {
            TrailSegment(route: $0, parkName: "Amelia Earhart Park")
        }
        let virginiaKey = TrailMapData.routes(for: "virginia-key").map {
            TrailSegment(route: $0, parkName: "Virginia Key North Point")
        }
        return TrailGraph(segments: amelia + virginiaKey)
    }

    func node(near coordinate: CLLocationCoordinate2D, thresholdMeters: CLLocationDistance = 18) -> TrailNode? {
        nodes
            .map { ($0, $0.coordinate.distance(to: coordinate)) }
            .filter { $0.1 <= thresholdMeters }
            .min { $0.1 < $1.1 }?
            .0
    }

    func segment(id: String) -> TrailSegment? {
        segments.first { $0.id == id }
    }

    private static func buildNodes(from segments: [TrailSegment]) -> [TrailNode] {
        var buckets: [(coordinate: CLLocationCoordinate2D, segmentIDs: Set<String>)] = []

        for segment in segments {
            for coordinate in [segment.coordinates.first, segment.coordinates.last].compactMap({ $0 }) {
                if let index = buckets.firstIndex(where: { $0.coordinate.distance(to: coordinate) <= 18 }) {
                    buckets[index].segmentIDs.insert(segment.id)
                } else {
                    buckets.append((coordinate, [segment.id]))
                }
            }
        }

        return buckets.enumerated().map { index, bucket in
            TrailNode(
                id: "node-\(index)",
                coordinate: bucket.coordinate,
                connectedSegmentIDs: Array(bucket.segmentIDs).sorted()
            )
        }
    }
}

struct TrailNode: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let connectedSegmentIDs: [String]

    var isIntersection: Bool {
        connectedSegmentIDs.count > 1
    }
}

struct TrailSegment: Identifiable {
    let id: String
    let name: String
    let difficulty: String
    let parkName: String
    let coordinates: [CLLocationCoordinate2D]
    let cumulativeDistances: [CLLocationDistance]
    let distanceMeters: CLLocationDistance
    let featureTags: [String]

    init(route: TrailRoute, parkName: String) {
        self.id = "\(parkName)-\(route.id)"
        self.name = route.name
        self.difficulty = route.difficulty
        self.parkName = parkName
        self.coordinates = route.coordinates
        self.cumulativeDistances = Self.cumulativeDistances(for: route.coordinates)
        self.distanceMeters = cumulativeDistances.last ?? 0

        let normalizedDifficulty = route.difficulty.lowercased()
        if normalizedDifficulty.contains("black") || normalizedDifficulty.contains("advanced") {
            self.featureTags = ["Technical"]
        } else {
            self.featureTags = []
        }
    }

    func coordinate(at distanceMeters: CLLocationDistance) -> CLLocationCoordinate2D? {
        guard coordinates.count > 1 else { return coordinates.first }

        let clampedDistance = min(max(distanceMeters, 0), self.distanceMeters)
        guard clampedDistance > 0 else { return coordinates.first }
        guard clampedDistance < self.distanceMeters else { return coordinates.last }

        for index in 1..<cumulativeDistances.count {
            let startDistance = cumulativeDistances[index - 1]
            let endDistance = cumulativeDistances[index]
            guard clampedDistance <= endDistance else { continue }

            let span = max(endDistance - startDistance, 0.0001)
            let progress = (clampedDistance - startDistance) / span
            return coordinates[index - 1].interpolated(to: coordinates[index], fraction: progress)
        }

        return coordinates.last
    }

    func coordinates(from startDistance: CLLocationDistance, to endDistance: CLLocationDistance) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 1 else { return coordinates }

        let lower = min(max(min(startDistance, endDistance), 0), distanceMeters)
        let upper = min(max(max(startDistance, endDistance), 0), distanceMeters)
        var slice: [CLLocationCoordinate2D] = []

        if let start = coordinate(at: lower) {
            slice.append(start)
        }

        for (index, coordinate) in coordinates.enumerated() {
            let distance = cumulativeDistances[index]
            if distance > lower && distance < upper {
                slice.append(coordinate)
            }
        }

        if let end = coordinate(at: upper) {
            slice.append(end)
        }

        if startDistance > endDistance {
            slice.reverse()
        }

        return slice
    }

    private static func cumulativeDistances(for coordinates: [CLLocationCoordinate2D]) -> [CLLocationDistance] {
        guard !coordinates.isEmpty else { return [] }

        var distances: [CLLocationDistance] = [0]
        var total: CLLocationDistance = 0

        for index in 1..<coordinates.count {
            total += coordinates[index - 1].distance(to: coordinates[index])
            distances.append(total)
        }

        return distances
    }
}

struct TrailLocationMatch {
    let segment: TrailSegment
    let snappedCoordinate: CLLocationCoordinate2D
    let distanceAlongSegmentMeters: CLLocationDistance
    let lateralDistanceMeters: CLLocationDistance
    let confidence: TrailNavigationConfidence
    let isReverseTravel: Bool

    var progressFraction: Double {
        guard segment.distanceMeters > 0 else { return 0 }
        return min(max(distanceAlongSegmentMeters / segment.distanceMeters, 0), 1)
    }
}

struct RideNavigationEngine {
    static func navigationState(
        for location: CLLocation?,
        graph: TrailGraph,
        signalQuality: LocationSignalQuality,
        lookaheadMeters: CLLocationDistance = 220
    ) -> TrailNavigationState {
        guard let location else {
            return TrailNavigationState(
                currentTrailName: "Finding trail",
                currentDifficulty: "",
                parkName: "",
                statusText: signalQuality.label,
                confidence: .unknown,
                signalQuality: signalQuality,
                progressFraction: 0,
                directionalProgressFraction: 0,
                distanceAlongSegmentMeters: 0,
                remainingSegmentMeters: 0,
                distanceToTrailMeters: nil,
                lookaheadMeters: lookaheadMeters,
                matchedCoordinate: nil,
                currentSegmentCoordinates: [],
                visibleAheadCoordinates: [],
                upcomingForkChoices: [],
                cue: RideNavigationCue(
                    kind: .gpsWeak,
                    title: "GPS acquiring",
                    detail: "Keep rolling while the app finds a usable fix.",
                    distanceMeters: nil
                )
            )
        }

        guard let match = match(location: location, in: graph) else {
            return TrailNavigationState(
                currentTrailName: "Off trail",
                currentDifficulty: "",
                parkName: "",
                statusText: "No nearby mapped trail",
                confidence: .offRoute,
                signalQuality: signalQuality,
                progressFraction: 0,
                directionalProgressFraction: 0,
                distanceAlongSegmentMeters: 0,
                remainingSegmentMeters: 0,
                distanceToTrailMeters: nil,
                lookaheadMeters: lookaheadMeters,
                matchedCoordinate: nil,
                currentSegmentCoordinates: [],
                visibleAheadCoordinates: [],
                upcomingForkChoices: [],
                cue: RideNavigationCue(
                    kind: .offRoute,
                    title: "Off route",
                    detail: "Nearest mapped trail is outside guidance range.",
                    distanceMeters: nil
                )
            )
        }

        let aheadEndDistance = match.isReverseTravel
            ? max(0, match.distanceAlongSegmentMeters - lookaheadMeters)
            : min(match.segment.distanceMeters, match.distanceAlongSegmentMeters + lookaheadMeters)
        let visibleAhead = match.segment.coordinates(
            from: match.distanceAlongSegmentMeters,
            to: aheadEndDistance
        )
        let remainingSegmentMeters = match.isReverseTravel
            ? match.distanceAlongSegmentMeters
            : max(match.segment.distanceMeters - match.distanceAlongSegmentMeters, 0)
        let directionalProgressFraction = match.isReverseTravel
            ? 1 - match.progressFraction
            : match.progressFraction
        let forkChoices = upcomingForkChoices(for: match, graph: graph, lookaheadMeters: lookaheadMeters)
        let cue = cue(
            for: match,
            forkChoices: forkChoices,
            signalQuality: signalQuality,
            lookaheadMeters: lookaheadMeters
        )

        return TrailNavigationState(
            currentTrailName: match.segment.name,
            currentDifficulty: match.segment.difficulty,
            parkName: match.segment.parkName,
            statusText: statusText(for: match, signalQuality: signalQuality),
            confidence: match.confidence,
            signalQuality: signalQuality,
            progressFraction: match.progressFraction,
            directionalProgressFraction: min(max(directionalProgressFraction, 0), 1),
            distanceAlongSegmentMeters: match.distanceAlongSegmentMeters,
            remainingSegmentMeters: remainingSegmentMeters,
            distanceToTrailMeters: match.lateralDistanceMeters,
            lookaheadMeters: lookaheadMeters,
            matchedCoordinate: match.snappedCoordinate,
            currentSegmentCoordinates: match.segment.coordinates,
            visibleAheadCoordinates: visibleAhead,
            upcomingForkChoices: forkChoices,
            cue: cue
        )
    }

    static func match(location: CLLocation, in graph: TrailGraph) -> TrailLocationMatch? {
        guard !graph.segments.isEmpty else { return nil }

        // Find the closest edge first; only the winner's confidence and
        // reverse-travel are needed, so compute those once after the scan
        // rather than for every edge on each (per-second) location update.
        var bestSegment: TrailSegment?
        var bestSnapped: CLLocationCoordinate2D?
        var bestDistanceAlong: CLLocationDistance = 0
        var bestLateral: CLLocationDistance = .greatestFiniteMagnitude

        for segment in graph.segments where segment.coordinates.count > 1 {
            for index in 0..<(segment.coordinates.count - 1) {
                let start = segment.coordinates[index]
                let end = segment.coordinates[index + 1]
                let projection = project(location.coordinate, ontoLineFrom: start, to: end)
                guard projection.distanceMeters < bestLateral else { continue }

                let edgeDistance = segment.cumulativeDistances[index + 1] - segment.cumulativeDistances[index]
                bestLateral = projection.distanceMeters
                bestSegment = segment
                bestSnapped = projection.coordinate
                bestDistanceAlong = segment.cumulativeDistances[index] + edgeDistance * projection.fraction
            }
        }

        guard let bestSegment, let bestSnapped, bestLateral <= 55 else { return nil }

        return TrailLocationMatch(
            segment: bestSegment,
            snappedCoordinate: bestSnapped,
            distanceAlongSegmentMeters: bestDistanceAlong,
            lateralDistanceMeters: bestLateral,
            confidence: confidence(
                lateralDistanceMeters: bestLateral,
                horizontalAccuracy: location.horizontalAccuracy
            ),
            isReverseTravel: isReverseTravel(
                course: location.course,
                segment: bestSegment,
                distanceAlongSegmentMeters: bestDistanceAlong
            )
        )
    }

    private static func cue(
        for match: TrailLocationMatch,
        forkChoices: [TrailForkChoice],
        signalQuality: LocationSignalQuality,
        lookaheadMeters: CLLocationDistance
    ) -> RideNavigationCue? {
        if signalQuality == .weak || signalQuality == .stale {
            return RideNavigationCue(
                kind: .gpsWeak,
                title: signalQuality == .stale ? "GPS stale" : "GPS weak",
                detail: "Trail guidance is estimated until signal improves.",
                distanceMeters: nil
            )
        }

        if match.confidence == .low {
            return RideNavigationCue(
                kind: .gpsWeak,
                title: "Trail match weak",
                detail: "Position is near the edge of the mapped trail.",
                distanceMeters: match.lateralDistanceMeters
            )
        }

        if let forkCue = upcomingForkCue(for: match, forkChoices: forkChoices, lookaheadMeters: lookaheadMeters) {
            return forkCue
        }

        if let curveCue = upcomingCurveCue(for: match, lookaheadMeters: lookaheadMeters) {
            return curveCue
        }

        if match.segment.featureTags.contains("Technical") {
            return RideNavigationCue(
                kind: .technical,
                title: "Technical trail",
                detail: "\(match.segment.difficulty) section. Keep the line visible.",
                distanceMeters: nil
            )
        }

        return nil
    }

    private static func upcomingForkCue(
        for match: TrailLocationMatch,
        forkChoices: [TrailForkChoice],
        lookaheadMeters: CLLocationDistance
    ) -> RideNavigationCue? {
        guard let firstChoice = forkChoices.first,
              firstChoice.distanceMeters <= min(lookaheadMeters, 120) else { return nil }

        let options = forkChoices.prefix(2).map(\.displayText).joined(separator: ", ")
        let extraCount = max(forkChoices.count - 2, 0)
        let detail = extraCount > 0
            ? "\(options), +\(extraCount) more."
            : options

        return RideNavigationCue(
            kind: .fork,
            title: "Trail split ahead",
            detail: detail,
            distanceMeters: firstChoice.distanceMeters
        )
    }

    private static func upcomingForkChoices(
        for match: TrailLocationMatch,
        graph: TrailGraph,
        lookaheadMeters: CLLocationDistance
    ) -> [TrailForkChoice] {
        let distanceToEndpoint = match.isReverseTravel
            ? match.distanceAlongSegmentMeters
            : match.segment.distanceMeters - match.distanceAlongSegmentMeters

        guard distanceToEndpoint <= min(lookaheadMeters, 120) else { return [] }

        let endpoint = match.isReverseTravel ? match.segment.coordinates.first : match.segment.coordinates.last
        guard let endpoint,
              let node = graph.node(near: endpoint),
              node.isIntersection,
              let approachBearing = approachBearing(for: match, endpoint: endpoint) else {
            return []
        }

        return node.connectedSegmentIDs
            .compactMap { segmentID -> TrailForkChoice? in
                guard segmentID != match.segment.id,
                      let segment = graph.segment(id: segmentID),
                      let outboundBearing = outboundBearing(from: endpoint, on: segment) else {
                    return nil
                }

                return TrailForkChoice(
                    id: segment.id,
                    trailName: segment.name,
                    difficulty: segment.difficulty,
                    direction: forkDirection(from: approachBearing, to: outboundBearing),
                    bearingDegrees: outboundBearing,
                    distanceMeters: distanceToEndpoint
                )
            }
            .sorted { lhs, rhs in
                if lhs.direction.sortPriority == rhs.direction.sortPriority {
                    return lhs.trailName < rhs.trailName
                }
                return lhs.direction.sortPriority < rhs.direction.sortPriority
            }
    }

    private static func upcomingCurveCue(
        for match: TrailLocationMatch,
        lookaheadMeters: CLLocationDistance
    ) -> RideNavigationCue? {
        let directionMultiplier: CLLocationDistance = match.isReverseTravel ? -1 : 1
        let nearDistance = match.distanceAlongSegmentMeters + (25 * directionMultiplier)
        let farDistance = match.distanceAlongSegmentMeters + (65 * directionMultiplier)

        guard abs(nearDistance - match.distanceAlongSegmentMeters) <= lookaheadMeters,
              let current = match.segment.coordinate(at: match.distanceAlongSegmentMeters),
              let near = match.segment.coordinate(at: nearDistance),
              let far = match.segment.coordinate(at: farDistance) else {
            return nil
        }

        let origin = near
        let currentPoint = ProjectedPoint(coordinate: current, origin: origin)
        let nearPoint = ProjectedPoint(coordinate: near, origin: origin)
        let farPoint = ProjectedPoint(coordinate: far, origin: origin)
        let incoming = CGVector(dx: nearPoint.x - currentPoint.x, dy: nearPoint.y - currentPoint.y)
        let outgoing = CGVector(dx: farPoint.x - nearPoint.x, dy: farPoint.y - nearPoint.y)
        let angle = angleBetween(incoming, outgoing)

        guard abs(angle) >= 40 else { return nil }

        let turnsLeft = angle > 0
        return RideNavigationCue(
            kind: turnsLeft ? .curveLeft : .curveRight,
            title: turnsLeft ? "Left curve" : "Right curve",
            detail: abs(angle) > 70 ? "Sharp bend in the trail." : "Curve coming up.",
            distanceMeters: 25
        )
    }

    private static func approachBearing(
        for match: TrailLocationMatch,
        endpoint: CLLocationCoordinate2D
    ) -> CLLocationDirection? {
        if match.isReverseTravel {
            guard let approach = match.segment.coordinate(at: min(18, match.segment.distanceMeters)) else {
                return nil
            }
            return approach.bearing(to: endpoint)
        }

        guard let approach = match.segment.coordinate(at: max(match.segment.distanceMeters - 18, 0)) else {
            return nil
        }
        return approach.bearing(to: endpoint)
    }

    private static func outboundBearing(
        from endpoint: CLLocationCoordinate2D,
        on segment: TrailSegment
    ) -> CLLocationDirection? {
        guard segment.coordinates.count > 1 else { return nil }

        let distanceToStart = endpoint.distance(to: segment.coordinates[0])
        let distanceToEnd = endpoint.distance(to: segment.coordinates[segment.coordinates.count - 1])

        if distanceToStart <= distanceToEnd {
            guard let outbound = segment.coordinate(at: min(18, segment.distanceMeters)) else { return nil }
            return endpoint.bearing(to: outbound)
        }

        guard let outbound = segment.coordinate(at: max(segment.distanceMeters - 18, 0)) else { return nil }
        return endpoint.bearing(to: outbound)
    }

    private static func forkDirection(
        from approachBearing: CLLocationDirection,
        to outboundBearing: CLLocationDirection
    ) -> TrailForkDirection {
        let delta = signedAngularDifferenceDegrees(from: approachBearing, to: outboundBearing)
        let absoluteDelta = abs(delta)

        if absoluteDelta <= 22 {
            return .straight
        }
        if absoluteDelta <= 55 {
            return delta < 0 ? .slightLeft : .slightRight
        }
        if absoluteDelta <= 120 {
            return delta < 0 ? .left : .right
        }
        if absoluteDelta <= 160 {
            return delta < 0 ? .hardLeft : .hardRight
        }
        return .back
    }

    private static func statusText(
        for match: TrailLocationMatch,
        signalQuality: LocationSignalQuality
    ) -> String {
        if signalQuality == .weak || signalQuality == .stale {
            return signalQuality.label
        }
        if match.confidence == .high {
            return "On \(match.segment.name)"
        }
        return match.confidence.label
    }

    private static func confidence(
        lateralDistanceMeters: CLLocationDistance,
        horizontalAccuracy: CLLocationAccuracy
    ) -> TrailNavigationConfidence {
        let accuracy = horizontalAccuracy >= 0 ? horizontalAccuracy : 30
        let adjustedDistance = max(lateralDistanceMeters - accuracy * 0.35, 0)

        if adjustedDistance <= 12 {
            return .high
        }
        if adjustedDistance <= 26 {
            return .medium
        }
        return .low
    }

    private static func isReverseTravel(
        course: CLLocationDirection,
        segment: TrailSegment,
        distanceAlongSegmentMeters: CLLocationDistance
    ) -> Bool {
        guard course >= 0,
              let before = segment.coordinate(at: max(distanceAlongSegmentMeters - 12, 0)),
              let after = segment.coordinate(at: min(distanceAlongSegmentMeters + 12, segment.distanceMeters)) else {
            return false
        }

        let bearing = before.bearing(to: after)
        return angularDifferenceDegrees(course, bearing) > 90
    }

    private static func project(
        _ coordinate: CLLocationCoordinate2D,
        ontoLineFrom start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> (coordinate: CLLocationCoordinate2D, fraction: Double, distanceMeters: CLLocationDistance) {
        let origin = start
        let point = ProjectedPoint(coordinate: coordinate, origin: origin)
        let lineStart = ProjectedPoint(coordinate: start, origin: origin)
        let lineEnd = ProjectedPoint(coordinate: end, origin: origin)
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy

        guard lengthSquared > 0 else {
            return (start, 0, coordinate.distance(to: start))
        }

        let rawFraction = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        let fraction = min(max(rawFraction, 0), 1)
        let snapped = start.interpolated(to: end, fraction: fraction)
        return (snapped, fraction, coordinate.distance(to: snapped))
    }

    private static func angleBetween(_ a: CGVector, _ b: CGVector) -> Double {
        let cross = a.dx * b.dy - a.dy * b.dx
        let dot = a.dx * b.dx + a.dy * b.dy
        return atan2(cross, dot) * 180 / .pi
    }

    private static func angularDifferenceDegrees(_ a: Double, _ b: Double) -> Double {
        let difference = abs(a - b).truncatingRemainder(dividingBy: 360)
        return difference > 180 ? 360 - difference : difference
    }

    private static func signedAngularDifferenceDegrees(from start: Double, to end: Double) -> Double {
        (end - start + 540).truncatingRemainder(dividingBy: 360) - 180
    }
}

private extension TrailForkDirection {
    var sortPriority: Int {
        switch self {
        case .straight: 0
        case .slightLeft, .slightRight: 1
        case .left, .right: 2
        case .hardLeft, .hardRight: 3
        case .back: 4
        }
    }
}

/// Equirectangular (local-tangent-plane) projection of a coordinate to meters
/// relative to `origin`. Shared by the navigation engine and trail-ahead ribbon.
struct ProjectedPoint {
    let x: Double
    let y: Double

    init(coordinate: CLLocationCoordinate2D, origin: CLLocationCoordinate2D) {
        let metersPerDegreeLatitude = 111_132.92
        let metersPerDegreeLongitude = 111_412.84 * cos(origin.latitude * .pi / 180)
        self.x = (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude
        self.y = (coordinate.latitude - origin.latitude) * metersPerDegreeLatitude
    }
}

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    func bearing(to other: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLongitude = (other.longitude - longitude) * .pi / 180
        let y = sin(deltaLongitude) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLongitude)
        let bearing = atan2(y, x) * 180 / .pi
        return bearing >= 0 ? bearing : bearing + 360
    }

    func interpolated(to other: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude + (other.latitude - latitude) * fraction,
            longitude: longitude + (other.longitude - longitude) * fraction
        )
    }
}
