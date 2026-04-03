import Foundation
import CoreLocation
import FirebaseFirestore

@Observable
@MainActor
final class TrailCreatorViewModel {

    enum RecordingState {
        case idle, recording, saving
    }

    // MARK: - State

    var recordingState: RecordingState = .idle
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var elapsedSeconds: Int = 0
    var distanceMiles: Double = 0
    var drafts: [CommunityTrail] = []
    var detectedPark: Park?
    var isLoading = false
    var errorMessage: String?
    var showDraftSaved = false

    // MARK: - Private

    private let locationService = LocationService.shared
    private let trailService = CommunityTrailService.shared
    private var timer: Timer?
    private var startTime: Date?
    private var lastLocation: CLLocation?

    // MARK: - Computed

    var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDistance: String {
        String(format: "%.2f", distanceMiles)
    }

    // MARK: - Controls

    func startRecording() {
        locationService.requestAlwaysPermission()
        locationService.startTracking()

        recordingState = .recording
        startTime = Date()
        elapsedSeconds = 0
        distanceMiles = 0
        routeCoordinates = []
        lastLocation = nil
        detectedPark = nil
        errorMessage = nil
        showDraftSaved = false

        startTimer()
    }

    func stopRecording(userId: String, username: String) async {
        stopTimer()
        locationService.stopTracking()
        recordingState = .saving

        // Calculate center coordinate from route
        let centerCoord: CLLocationCoordinate2D
        if routeCoordinates.isEmpty {
            centerCoord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        } else {
            let avgLat = routeCoordinates.map(\.latitude).reduce(0, +) / Double(routeCoordinates.count)
            let avgLon = routeCoordinates.map(\.longitude).reduce(0, +) / Double(routeCoordinates.count)
            centerCoord = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        }

        // Find park containing the route center
        do {
            let park = try await trailService.findPark(
                latitude: centerCoord.latitude,
                longitude: centerCoord.longitude
            )
            detectedPark = park

            // Build draft CommunityTrail
            let trail = CommunityTrail(
                creatorId: userId,
                creatorUsername: username,
                name: "New Trail",
                description: "",
                difficulty: .intermediate,
                trailType: .singletrack,
                direction: .loop,
                features: [],
                routeCoordinates: routeCoordinates.map {
                    GeoPoint(latitude: $0.latitude, longitude: $0.longitude)
                },
                distanceMiles: distanceMiles,
                parkId: park?.id,
                photoURLs: [],
                conditionReport: nil,
                conditionDate: nil,
                status: .draft,
                verificationCount: 0,
                isVerified: false,
                flagCount: 0,
                createdAt: Date(),
                updatedAt: Date()
            )

            _ = try await trailService.saveDraft(trail)
            showDraftSaved = true
        } catch {
            errorMessage = "Failed to save draft: \(error.localizedDescription)"
        }

        recordingState = .idle
        await loadDrafts(userId: userId)
    }

    // MARK: - Draft Management

    func loadDrafts(userId: String) async {
        isLoading = true
        do {
            drafts = try await trailService.getDrafts(userId: userId)
        } catch {
            errorMessage = "Failed to load drafts: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func updateDraft(_ trail: CommunityTrail) async {
        guard let trailId = trail.id else { return }
        do {
            let fields: [String: Any] = [
                "name": trail.name,
                "description": trail.description,
                "difficulty": trail.difficulty.rawValue,
                "trailType": trail.trailType.rawValue,
                "direction": trail.direction.rawValue,
                "features": trail.features,
                "conditionReport": trail.conditionReport?.rawValue as Any,
                "conditionDate": trail.conditionDate as Any,
                "updatedAt": trail.updatedAt
            ]
            try await trailService.updateTrail(id: trailId, fields: fields)
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }

    func publishDraft(_ trail: CommunityTrail, parkName: String?) async {
        guard let trailId = trail.id else { return }

        do {
            // If no parkId but a parkName was provided, create a new park
            if trail.parkId == nil, let parkName, !parkName.isEmpty {
                let coords = trail.routeCoordinates
                let avgLat = coords.isEmpty ? 0 : coords.map(\.latitude).reduce(0, +) / Double(coords.count)
                let avgLon = coords.isEmpty ? 0 : coords.map(\.longitude).reduce(0, +) / Double(coords.count)

                let newPark = Park(
                    name: parkName,
                    centerLatitude: avgLat,
                    centerLongitude: avgLon,
                    radiusMeters: 500,
                    maintainerIds: [],
                    trailCount: 0,
                    createdBy: trail.creatorId,
                    createdAt: Date()
                )
                let parkId = try await trailService.createPark(newPark)
                try await trailService.updateTrail(id: trailId, fields: [
                    "parkId": parkId,
                    "status": CommunityTrail.Status.published.rawValue,
                    "updatedAt": Date()
                ])
            } else {
                try await trailService.publishTrail(id: trailId)
            }

            if let userId = trail.creatorId as String? {
                await loadDrafts(userId: userId)
            }
        } catch {
            errorMessage = "Failed to publish trail: \(error.localizedDescription)"
        }
    }

    func deleteDraft(_ trail: CommunityTrail) async {
        guard let trailId = trail.id else { return }
        do {
            try await trailService.deleteDraft(id: trailId)
            drafts.removeAll { $0.id == trailId }
        } catch {
            errorMessage = "Failed to delete draft: \(error.localizedDescription)"
        }
    }

    // MARK: - Timer

    private func startTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if let start = startTime {
            elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
        recordLocation()
    }

    private func recordLocation() {
        guard let location = locationService.currentLocation else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 30 else { return }

        if let last = lastLocation {
            let delta = location.distance(from: last)
            guard delta > 2 && delta < 100 else { return }
            distanceMiles += delta / 1609.344
            routeCoordinates.append(location.coordinate)
        } else {
            routeCoordinates.append(location.coordinate)
        }

        lastLocation = location
    }
}
